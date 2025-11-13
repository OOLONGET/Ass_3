data <- utils::read.csv(infile, stringsAsFactors = FALSE, check.names = TRUE)
candidate_inputs <- c("out/eda_model_ready.csv", "./out/eda_model_ready.csv")
infile <- NULL
for (path in candidate_inputs) {
  if (file.exists(path)) {
    infile <- path
    break
  }
}
if (is.null(infile)) {
  stop("Input file eda_model_ready.csv not found. Checked: ", paste(candidate_inputs, collapse = ", "))
}

data <- utils::read.csv(infile, stringsAsFactors = FALSE, check.names = TRUE)
message("Debug: Rows = ", nrow(data), ", columns = ", ncol(data))

if (nrow(data) == 0L) {
  stop("Input data has zero rows; cannot fit regression model.")
}

lower_names <- tolower(names(data))
preferred_dv <- c("headcount", "total", "totals", "enrol", "enrolment", "enrollment", "count")
match_idx <- match(preferred_dv, lower_names)
match_idx <- match_idx[!is.na(match_idx)]
if (length(match_idx) > 0L) {
  dv <- names(data)[match_idx[1]]
} else {
  numeric_cols <- names(data)[vapply(data, is.numeric, logical(1L))]
  if (length(numeric_cols) == 0L) {
    stop("No numeric column found for dependent variable.")
  }
  dv <- numeric_cols[1]
}
message("Debug: Using dependent variable: ", dv)

data[[dv]] <- suppressWarnings(as.numeric(data[[dv]]))
if (all(is.na(data[[dv]]))) {
  stop("Dependent variable contains no numeric values after coercion.")
}

data <- data[!is.na(data[[dv]]), , drop = FALSE]
if (nrow(data) == 0L) {
  stop("All rows were removed after filtering missing dependent variable values.")
}

predictor_cols <- setdiff(names(data), dv)
if (length(predictor_cols) == 0L) {
  stop("No predictors available once dependent variable is removed.")
}

# Keep only predictors with at least two distinct non-NA values
predictor_cols <- predictor_cols[vapply(data[predictor_cols], function(col) {
  vals <- col[!is.na(col)]
  length(vals) > 0L && length(unique(vals)) > 1L
}, logical(1L))]

if (length(predictor_cols) == 0L) {
  stop("No predictors with sufficient variation remain.")
}

max_levels <- 30L
lump_factor <- function(x, max_levels) {
  if (!is.factor(x)) x <- factor(x)
  lvl_count <- length(levels(x))
  if (lvl_count <= max_levels) {
    return(x)
  }
  freq <- sort(table(x), decreasing = TRUE)
  keep <- names(freq)[seq_len(min(max_levels - 1L, length(freq)))]
  as.factor(ifelse(x %in% keep, as.character(x), "OTHER"))
}

model_data <- data[, c(dv, predictor_cols), drop = FALSE]
model_data[predictor_cols] <- lapply(model_data[predictor_cols], function(col) {
  if (is.character(col) || is.logical(col)) {
    return(lump_factor(col, max_levels))
  }
  if (is.factor(col)) {
    return(lump_factor(col, max_levels))
  }
  suppressWarnings(as.numeric(col))
})

valid_predictors <- predictor_cols[vapply(model_data[predictor_cols], function(col) {
  any(!is.na(col))
}, logical(1L))]

if (length(valid_predictors) == 0L) {
  stop("All predictors became NA after preprocessing.")
}

model_data <- model_data[, c(dv, valid_predictors), drop = FALSE]
formula <- stats::as.formula(paste(dv, "~", paste(valid_predictors, collapse = " + ")))
message("Debug: Regression formula: ", deparse(formula))

message("Debug: Fitting regression model...")
model <- lm(formula, data = model_data)
summary(model)

# Quick diagnostic outputs
residuals <- resid(model)
shapiro_test <- NULL
resid_len <- length(residuals)
if (resid_len < 3L) {
  message("Debug: Skipping Shapiro-Wilk test because fewer than 3 residuals are available.")
} else {
  if (resid_len > 5000L) {
    message("Debug: Residual count (", resid_len, ") exceeds 5000; taking random sample of 5000 for Shapiro-Wilk test.")
    set.seed(42)
    residuals_sample <- sample(residuals, 5000L)
    shapiro_test <- shapiro.test(residuals_sample)
  } else {
    shapiro_test <- shapiro.test(residuals)
  }
  if (!is.null(shapiro_test)) {
    message("Shapiro-Wilk p-value: ", signif(shapiro_test$p.value, 4))
  }
}

output_dir <- "out_Reg"
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

# Save plots
plot_path <- file.path(output_dir, "regression_plot.png")
png(plot_path, width = 900, height = 700)
plot(fitted(model), model_data[[dv]], main = "Observed vs Fitted", xlab = "Fitted", ylab = dv)
abline(0, 1, col = "red")
dev.off()

qqplot_path <- file.path(output_dir, "qq_plot.png")
png(qqplot_path, width = 900, height = 700)
qqnorm(residuals)
qqline(residuals, col = "blue")
dev.off()

results_path <- file.path(output_dir, "regression_results.txt")
sink(results_path)
cat("Regression Formula:\n")
print(formula)
cat("\nModel Summary:\n")
print(summary(model))
if (is.null(shapiro_test)) {
  cat("\nShapiro-Wilk Test: not computed (insufficient or too many residuals).\n")
} else {
  cat("\nShapiro-Wilk Test:\n")
  print(shapiro_test)
}
sink()
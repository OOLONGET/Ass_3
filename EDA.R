# R/01_eda.R
# 仅 base R（utils, graphics, grDevices, stats)

# Allow infile as a command-line argument; otherwise try several candidate paths.
cmd_args <- commandArgs(trailingOnly = TRUE)
if(length(cmd_args) > 0 && nzchar(cmd_args[1])){
  infile <- cmd_args[1]
} else {
  candidate_paths <- c(
    file.path("project/data/university_enrolment.csv")
  )
  infile <- NULL
  for(p in candidate_paths){
    if(file.exists(p)){
      infile <- p
      break
    }
  }
}
if(is.null(infile) || !file.exists(infile)){
  message("Could not find data file 'university_enrolment.csv'. Searched paths:\n",
          paste(if(exists("candidate_paths")) candidate_paths else "(no candidates)", collapse = "\n"), "\n\n")
  message("Current working directory: ", getwd(), "\nContents:\n")
  print(list.files(recursive = FALSE))
  stop("Please provide the data file. Run: Rscript EDA.R <path/to/university_enrolment.csv> or place the CSV in data/ and run from the project root.")
}

message("Using data file: ", infile)
dat <- utils::read.csv(infile, stringsAsFactors = FALSE, check.names = TRUE)

# Replace common suppression markers (e.g. "*") in character columns with NA
for(nm in names(dat)){
  if(is.character(dat[[nm]])){
    dat[[nm]][trimws(dat[[nm]]) == "*"] <- NA_character_
  }
}

# 基本信息
## Prefer container/IDE friendly path, fall back to project-local out/
preferred_paths <- c("/home/rstudio/project/out", "project/out")
out_dir <- NULL
for(p in preferred_paths){
  if(dir.exists(p)){
    # check writable
    if(file.access(p, 2) == 0){ out_dir <- p; break }
  } else {
    ok <- tryCatch(dir.create(p, recursive = TRUE, showWarnings = FALSE), error = function(e) FALSE)
    if(isTRUE(ok)){ out_dir <- p; break }
  }
}
if(is.null(out_dir)){
  stop("Could not create or write to any preferred output directories: ", paste(preferred_paths, collapse=", "))
}
sink(file.path(out_dir, "eda_summary.txt"))
cat("=== HEAD ===\n"); print(utils::head(dat, 10))
cat("\n=== STR ===\n");  utils::str(dat)
cat("\n=== SUMMARY ===\n"); print(summary(dat))
sink()

# 尝试识别关键字段（不同年份/大学）
# 这里做宽松匹配：列名里含 "year" 的作为年份，含 "univ" 的作为大学名称
coln <- tolower(colnames(dat))
year_col <- if (any(grepl("year", coln))) colnames(dat)[grepl("year", coln)][1] else NA
univ_col <- if (any(grepl("univ", coln))) colnames(dat)[grepl("univ", coln)][1] else NA

# 数值列挑选
message("Column classes (first 6 shown):")
print(sapply(dat, function(x) class(x))[1:min(6, ncol(dat))])

# Try to detect numeric columns; if none, attempt mild coercion (remove commas/% etc.)
is_num <- vapply(dat, function(x) is.numeric(x) || is.integer(x), logical(1))
num_cols <- names(which(is_num))

if(length(num_cols) == 0){
  message("No numeric columns detected initially — attempting robust coercion from character columns\n")
  # lower threshold so columns with many numeric-like strings (commas, NBSPs, % etc.) are caught
  coercion_threshold <- 0.20
  cleaned_any <- FALSE
  for(nm in names(dat)){
    col <- dat[[nm]]
    if(is.character(col)){
      # show a small sample to help debugging
      sample_vals <- unique(head(col, 6))
      message(sprintf("Checking column '%s' sample values: %s", nm, paste(sample_vals, collapse = " | ")))

      tmp <- col
      # remove non-breaking space and common thousands separators / currency / percent
      tmp <- gsub("\u00A0", "", tmp, fixed = TRUE)
      tmp <- gsub(",", "", tmp, fixed = TRUE)
      tmp <- gsub("%", "", tmp, fixed = TRUE)
      tmp <- gsub("\\$", "", tmp)
      tmp <- gsub("[()]", "", tmp)
      # remove whitespace and any remaining non-numeric characters except dot and minus
      tmp <- gsub("\\s+", "", tmp)
      tmp <- gsub("[^0-9.\\-]", "", tmp)

      suppressWarnings(num <- as.numeric(tmp))
      prop_num <- sum(is.finite(num), na.rm=TRUE) / max(1, length(num))
      if(prop_num >= coercion_threshold){
        dat[[nm]] <- num
        cleaned_any <- TRUE
        message(sprintf("Coerced column '%s' to numeric (%.1f%% non-missing numeric)", nm, prop_num * 100))
      } else {
        # heuristic: if many entries contain digits, coerce anyway (helps when many blanks/NA)
        digit_prop <- sum(grepl("[0-9]", col), na.rm=TRUE) / max(1, length(col))
        if(digit_prop >= 0.6){
          dat[[nm]] <- num
          cleaned_any <- TRUE
          message(sprintf("Heuristically coerced column '%s' to numeric based on digit proportion (%.1f%%)", nm, digit_prop * 100))
        } else {
          message(sprintf("Left column '%s' as character (%.1f%% numeric after cleaning)", nm, prop_num * 100))
        }
      }
    }
  }

  # recompute numeric columns
  is_num <- vapply(dat, function(x) is.numeric(x) || is.integer(x), logical(1))
  num_cols <- names(which(is_num))
  message("After coercion, numeric columns: ", if(length(num_cols) > 0) paste(head(num_cols, 10), collapse=", ") else "(none)")
  if(!cleaned_any) message("No character columns looked numeric enough to coerce — if you expect numeric fields, check their formatting (commas, currency symbols, non-breaking spaces).")
}

# Re-read raw original CSV to detect year-like columns that were wrongly coerced (e.g. '2023-2024')
raw_dat <- tryCatch(utils::read.csv(infile, stringsAsFactors = FALSE, check.names = TRUE), error = function(e) NULL)
if(!is.null(raw_dat) && length(num_cols) > 0){
  reverted <- character(0)
  for(nm in num_cols){
    if(nm %in% colnames(raw_dat)){
      orig <- as.character(raw_dat[[nm]])
      # proportion matching patterns like 2023-2024 or 2023/24
      prop_year <- mean(grepl("^\\s*\\d{4}\\s*[-/]\\s*\\d{2,4}\\s*$", orig))
      if(prop_year >= 0.6){
        # revert this column to its original character form
        dat[[nm]] <- orig
        reverted <- c(reverted, nm)
      }
    }
  }
  if(length(reverted) > 0){
    message("Reverted these year-like columns back to character (not numeric): ", paste(reverted, collapse=", "))
    # recompute numeric columns after revert
    is_num <- vapply(dat, function(x) is.numeric(x) || is.integer(x), logical(1))
    num_cols <- names(which(is_num))
    message("Numeric columns after reverting year-like fields: ", if(length(num_cols)>0) paste(head(num_cols,10), collapse=", ") else "(none)")
  }
}

## Visualizations (base R) - write several useful plots into out_dir
if(length(num_cols) == 0){
  message("No numeric columns found; skipping visualizations.")
} else {
  nplot <- min(6, length(num_cols))

  # choose a compact layout based on number of plots so single plots are centered
  make_layout <- function(n){
    if(n <= 1) return(c(1,1))
    if(n == 2) return(c(1,2))
    cols <- min(3, n)
    rows <- ceiling(n / cols)
    c(rows, cols)
  }

  # 1) Histograms (also produce log-histogram when strongly skewed)
  hist_file <- file.path(out_dir, "histograms.png")
  hist_w <- if(nplot <= 1) 800 else 1200
  hist_h <- if(nplot <= 1) 600 else 800
  png(hist_file, width = hist_w, height = hist_h)
  lo <- make_layout(nplot)
  par(mfrow = lo)
  for (nm in head(num_cols, nplot)) {
    x <- dat[[nm]]
    finite_x <- x[is.finite(x)]
    if(length(finite_x) < 2 || length(unique(finite_x)) < 2){
      message(sprintf("Skipping histogram for '%s' — not enough finite/unique numeric values.", nm))
      plot.new(); title(main = paste("No data for", nm))
      next
    }
    # avoid huge outliers dominating the view by focusing on the 99th percentile
    p99 <- as.numeric(stats::quantile(finite_x, probs = 0.99, na.rm = TRUE))
    p1 <- as.numeric(stats::quantile(finite_x, probs = 0.01, na.rm = TRUE))
    xlim <- c(min(finite_x, na.rm=TRUE), max(p99, p1))
    tryCatch(
      hist(finite_x, main = paste("Histogram of", nm), xlab = nm, col = "lightblue", border = "white", breaks = 50, xlim = xlim),
      error = function(e){ message(sprintf("Histogram failed for '%s': %s", nm, e$message)); plot.new(); title(main = paste("Error plotting", nm)) }
    )
  }
  dev.off()

  # add log-scale histograms for skewed variables
  log_skewed <- function(x){
    fx <- x[is.finite(x) & x > 0]
    if(length(fx) < 10) return(FALSE)
    med <- stats::median(fx, na.rm=TRUE)
    p99 <- as.numeric(stats::quantile(fx, probs = 0.99, na.rm = TRUE))
    return(p99 > (med * 10 + 1))
  }
  log_vars <- Filter(function(nm) log_skewed(dat[[nm]]), head(num_cols, nplot))
  if(length(log_vars) > 0){
    png(file.path(out_dir, "histograms_log.png"), width = 1000, height = 600)
    lo2 <- make_layout(length(log_vars))
    par(mfrow = lo2)
    for(nm in log_vars){
      x <- dat[[nm]]
      fx <- x[is.finite(x) & x > 0]
      tryCatch(
        hist(log1p(fx), breaks = 50, main = paste("Log(1+x) histogram of", nm), xlab = paste("log1p(", nm, ")"), col = "lightblue"),
        error = function(e) { message(sprintf("Log-hist failed for '%s': %s", nm, e$message)); plot.new(); title(main = paste("Error", nm)) }
      )
    }
    dev.off()
  }

  # 2) Boxplots
  bp_file <- file.path(out_dir, "boxplots.png")
  bp_w <- if(nplot <= 1) 800 else 1200
  bp_h <- if(nplot <= 1) 600 else 800
  png(bp_file, width = bp_w, height = bp_h)
  lo <- make_layout(nplot)
  par(mfrow = lo)
  for (nm in head(num_cols, nplot)) {
    x <- dat[[nm]]
    finite_x <- x[is.finite(x)]
    if(length(finite_x) < 1){
      message(sprintf("Skipping boxplot for '%s' — no finite numeric values.", nm))
      plot.new(); title(main = paste("No data for", nm))
      next
    }
    # limit ylim to 99th percentile to show central distribution; still show outliers
    p99 <- as.numeric(stats::quantile(finite_x, probs = 0.99, na.rm = TRUE))
    tryCatch(
      boxplot(x, main = paste("Boxplot of", nm), ylab = nm, col = "lightgreen", ylim = c(min(finite_x, na.rm=TRUE), p99)),
      error = function(e){ message(sprintf("Boxplot failed for '%s': %s", nm, e$message)); plot.new(); title(main = paste("Error plotting", nm)) }
    )
  }
  dev.off()

  # optional log-scale boxplots for skewed variables
  if(length(log_vars) > 0){
    png(file.path(out_dir, "boxplots_log.png"), width = 1000, height = 600)
    lo2 <- make_layout(length(log_vars))
    par(mfrow = lo2)
    for(nm in log_vars){
      x <- dat[[nm]]
      fx <- x[is.finite(x) & x > 0]
      tryCatch(
        boxplot(log1p(fx), main = paste("Log(1+x) boxplot of", nm), ylab = paste("log1p(", nm, ")"), col = "lightgreen"),
        error = function(e){ message(sprintf("Log-box failed for '%s': %s", nm, e$message)); plot.new(); title(main = paste("Error", nm)) }
      )
    }
    dev.off()
  }

  # 3) Pairs (scatter) for first up to 6 numeric cols
  if(length(num_cols) >= 2){
    # choose numeric columns with at least two finite values
    good_cols <- Filter(function(nm){
      x <- dat[[nm]]
      sum(is.finite(x)) >= 2 && length(unique(x[is.finite(x)])) >= 2
    }, num_cols)
    good_cols <- head(good_cols, nplot)
    if(length(good_cols) >= 2){
      png(file.path(out_dir, "pairs.png"), width = 1000, height = 1000)
      pairs(dat[ , good_cols, drop = FALSE], main = "Pairs plot (first numeric columns)")
      dev.off()
    } else {
      message("Skipping pairs plot — not enough numeric columns with sufficient data.")
    }
  }

  # 4) Correlation heatmap
  if(length(num_cols) >= 2){
    # compute correlation only on columns with enough finite values
    cors_cols <- Filter(function(nm){ sum(is.finite(dat[[nm]])) >= 2 }, num_cols)
    if(length(cors_cols) >= 2){
      cors <- stats::cor(dat[, cors_cols, drop = FALSE], use = "pairwise.complete.obs")
      png(file.path(out_dir, "corr_heatmap.png"), width = 900, height = 700)
      # use heatmap; set Rowv/Colv to NA to avoid clustering if undesired
      heatmap(cors, main = "Correlation heatmap", symm = TRUE)
      dev.off()
    } else {
      message("Skipping correlation heatmap — not enough numeric columns with sufficient data.")
    }
  }

  # 5) Simple annual trend for the first numeric column if a year column was found
  if(!is.na(year_col) && year_col %in% colnames(dat) && length(num_cols) >= 1){
    # coerce year to integer if possible
    yr <- suppressWarnings(as.integer(dat[[year_col]]))
    if(any(is.finite(yr))){
      first_num <- num_cols[1]
      agg <- tapply(dat[[first_num]], yr, sum, na.rm = TRUE)
      png(file.path(out_dir, "annual_trend.png"), width = 900, height = 500)
      plot(as.integer(names(agg)), agg, type = "b", pch = 19, col = "steelblue",
           xlab = year_col, ylab = paste("Sum of", first_num), main = "Annual trend")
      dev.off()
    }
  }

  message("Saved visualizations to: ", normalizePath(out_dir))
}

# 保存一个“分析就绪”的数值子集（可在回归中复用）
# Keep original cleaned values with NA preserved, and also provide an imputed copy
eda_ready <- dat

# Create an imputed copy where numeric NAs are filled with median (useful for quick models)
eda_ready_imputed <- eda_ready
for (nm in num_cols) {
  x <- eda_ready_imputed[[nm]]
  if (is.numeric(x)) {
    med <- stats::median(x, na.rm = TRUE)
    x[!is.finite(x)] <- NA
    x[is.na(x)] <- med
    eda_ready_imputed[[nm]] <- x
  }
}

tryCatch({
  utils::write.csv(eda_ready, file.path(out_dir, "eda_model_ready.csv"), row.names = FALSE)
  utils::write.csv(eda_ready_imputed, file.path(out_dir, "eda_model_ready_imputed.csv"), row.names = FALSE)
  message("EDA 完成：已生成 out/ 下的图表与 eda_model_ready.csv (原始缺失保留) 和 eda_model_ready_imputed.csv (中位数填补)")
}, error = function(e){
  message("写出 eda_model_ready 文件失败: ", e$message)
})

# ---- Variable selection: recommend dependent variable (DV) and independent variables (IVs) ----
message("Starting variable-selection step: summarise variables and recommend DV/IVs")

# identify numeric and categorical columns in eda_ready
numeric_cols <- names(which(vapply(eda_ready, function(x) is.numeric(x) || is.integer(x), logical(1))))
cat_cols <- setdiff(colnames(eda_ready), numeric_cols)

# treat detected year column as an identifier (exclude from DV candidates)
dv_exclude <- character(0)
if(!is.na(year_col) && year_col %in% colnames(eda_ready)) dv_exclude <- c(dv_exclude, year_col)

# summary for numeric cols
num_summary <- data.frame(variable = character(), n_non_na = integer(), n_unique = integer(), mean = numeric(), sd = numeric(), var = numeric(), stringsAsFactors = FALSE)
for(nm in numeric_cols){
  x <- eda_ready[[nm]]
  num_summary <- rbind(num_summary, data.frame(variable = nm,
                                               n_non_na = sum(is.finite(x)),
                                               n_unique = length(unique(x[is.finite(x)])),
                                               mean = mean(x, na.rm = TRUE),
                                               sd = stats::sd(x, na.rm = TRUE),
                                               var = stats::var(x, na.rm = TRUE),
                                               stringsAsFactors = FALSE))
}

# summary for categorical cols (count of levels, top levels)
cat_summary <- data.frame(variable = character(), n_levels = integer(), top_levels = character(), stringsAsFactors = FALSE)
for(nm in cat_cols){
  v <- as.character(eda_ready[[nm]])
  lv <- sort(table(v), decreasing = TRUE)
  topk <- paste(names(lv)[1:min(3, length(lv))], collapse = ", ")
  cat_summary <- rbind(cat_summary, data.frame(variable = nm, n_levels = length(lv), top_levels = topk, stringsAsFactors = FALSE))
}

tryCatch({
  utils::write.csv(num_summary, file.path(out_dir, "variable_summaries_numeric.csv"), row.names = FALSE)
  utils::write.csv(cat_summary, file.path(out_dir, "variable_summaries_categorical.csv"), row.names = FALSE)
}, error = function(e){ message("Failed to write variable summaries: ", e$message) })

# select candidate DV: numeric with largest variance and at least 10 unique values (prefer)
dv_candidates <- setdiff(num_summary$variable, dv_exclude)
dv_best <- NA
if(length(dv_candidates) > 0){
  # prefer those with >=10 unique values
  has_many <- dv_candidates[num_summary$n_unique[match(dv_candidates, num_summary$variable)] >= 10]
  pool <- if(length(has_many) > 0) has_many else dv_candidates
  # pick by largest variance
  pool_vars <- num_summary$variable %in% pool
  pool_df <- num_summary[pool_vars, , drop = FALSE]
  if(nrow(pool_df) > 0) dv_best <- pool_df$variable[which.max(pool_df$var)]
}

selection_txt <- file.path(out_dir, "eda_selection.txt")
sel_lines <- c()
if(is.na(dv_best)){
  sel_lines <- c(sel_lines, "No suitable numeric dependent variable found automatically.")
  message(sel_lines)
  writeLines(sel_lines, con = selection_txt)
} else {
  sel_lines <- c(sel_lines, paste("Recommended dependent variable (DV):", dv_best))
  message("Recommended DV: ", dv_best)

  # compute correlations with numeric predictors
  preds_num <- setdiff(numeric_cols, dv_best)
  cor_df <- data.frame(predictor = preds_num, cor = NA_real_, stringsAsFactors = FALSE)
  for(i in seq_along(preds_num)){
    p <- preds_num[i]
    v1 <- eda_ready[[dv_best]]
    v2 <- eda_ready[[p]]
    cor_df$cor[i] <- suppressWarnings(cor(v1, v2, use = "pairwise.complete.obs"))
  }
  cor_df$abs_cor <- abs(cor_df$cor)
  cor_df <- cor_df[order(-cor_df$abs_cor, na.last = TRUE), ]
  tryCatch(utils::write.csv(cor_df, file.path(out_dir, "correlation_with_dv.csv"), row.names = FALSE), error = function(e) message("Write cor_df failed: ", e$message))

  # rank categorical predictors by ANOVA F-statistic (dv ~ cat)
  cat_rank <- data.frame(predictor = character(), F_value = numeric(), p_value = numeric(), stringsAsFactors = FALSE)
  for(p in cat_cols){
    # skip entirely NA or single level
    grp <- as.character(eda_ready[[p]])
    if(length(unique(na.omit(grp))) < 2) next
    df_tmp <- data.frame(dv = eda_ready[[dv_best]], g = grp, stringsAsFactors = FALSE)
    a <- tryCatch(summary(aov(dv ~ g, data = df_tmp)), error = function(e) NULL)
    if(!is.null(a) && length(a) >= 1){
      # extract F value and p
      s <- a[[1]]
      if(nrow(s) >= 1){
        Fval <- as.numeric(s["g","F value"])
        pval <- as.numeric(s["g","Pr(>F)"])
        cat_rank <- rbind(cat_rank, data.frame(predictor = p, F_value = Fval, p_value = pval, stringsAsFactors = FALSE))
      }
    }
  }
  if(nrow(cat_rank) > 0) cat_rank <- cat_rank[order(-cat_rank$F_value, na.last = TRUE), ]
  tryCatch(utils::write.csv(cat_rank, file.path(out_dir, "categorical_predictor_ranking.csv"), row.names = FALSE), error = function(e) message("Write cat_rank failed: ", e$message))

  # combine top predictors into one file
  top_num <- head(cor_df$predictor, 10)
  top_cat <- head(cat_rank$predictor, 10)
  predictors <- data.frame(type = c(rep("numeric", length(top_num)), rep("categorical", length(top_cat))),
                           predictor = c(top_num, top_cat), stringsAsFactors = FALSE)
  tryCatch(utils::write.csv(predictors, file.path(out_dir, "predictor_rankings.csv"), row.names = FALSE), error = function(e) message("Write predictors failed: ", e$message))

  sel_lines <- c(sel_lines, "Top numeric predictors by |correlation| with DV (top 10):")
  if(nrow(cor_df) > 0) sel_lines <- c(sel_lines, capture.output(utils::head(cor_df, 10)))
  sel_lines <- c(sel_lines, "Top categorical predictors by ANOVA F (top 10):")
  if(nrow(cat_rank) > 0) sel_lines <- c(sel_lines, capture.output(utils::head(cat_rank, 10)))

  writeLines(sel_lines, con = selection_txt)
  message("Wrote variable selection outputs to: ", normalizePath(out_dir))
}

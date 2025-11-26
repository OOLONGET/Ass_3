# ==== 0. Load readxl ====
if (!requireNamespace("readxl", quietly = TRUE)) {
  install.packages("readxl")
}
library(readxl)

# ==== 1. Read Gender sheet ====
data_path_candidates <- c(
  "data/university_enrolment_headcount_2023-24.xlsx",
  "university_enrolment_headcount_2023-24.xlsx"
)

data_file <- NULL
for (p in data_path_candidates) {
  if (file.exists(p)) {
    data_file <- p
    break
  }
}

if (is.null(data_file)) {
  stop("Cannot find university_enrolment_headcount_2023-24.xlsx. Please check the path.")
}

cat("Using data file:", data_file, "\n")

df_gender <- read_excel(data_file, sheet = "Gender")

cat("\nFirst few rows of data:\n")
print(head(df_gender, 10))
cat("\nColumn names:\n")
print(names(df_gender))
str(df_gender)

# ==== 2. Basic cleaning: Fiscal Year → Year, HEADCOUNT → numeric ====

# Fiscal Year in the format "2012-2013", take the first 4 digits as Year
df_gender$Year <- as.integer(substr(df_gender$`Fiscal Year`, 1, 4))

# Convert HEADCOUNT to numeric (handle commas or special symbols)
df_gender$HEADCOUNT_num <- suppressWarnings(
  as.numeric(gsub(",", "", as.character(df_gender$HEADCOUNT)))
)

cat("\nNumber of NAs in HEADCOUNT after conversion:",
    sum(is.na(df_gender$HEADCOUNT_num)), "\n")

# Remove rows where HEADCOUNT cannot be converted to numeric
df_gender_clean <- subset(df_gender, !is.na(HEADCOUNT_num))

# ==== 3. EDA: All levels, all genders ====

# 3.1 Aggregate total headcount by Year (all levels + genders + universities)
agg_all <- aggregate(
  HEADCOUNT_num ~ Year,
  data = df_gender_clean,
  FUN = sum
)

cat("\nTotal headcount by year (all levels + genders):\n")
print(agg_all)

# ==== 4. EDA: Undergraduate only ====

df_ug <- subset(df_gender_clean, `Study Level` == "Undergraduate")

# 4.1 Aggregate undergraduate total headcount by Year
agg_ug <- aggregate(
  HEADCOUNT_num ~ Year,
  data = df_ug,
  FUN = sum
)

cat("\nUndergraduate total headcount by year:\n")
print(agg_ug)

# 4.2 Aggregate undergraduate headcount by Year + Gender Group (for modeling)
agg_ug_gender <- aggregate(
  HEADCOUNT_num ~ Year + `Gender Group`,
  data = df_ug,
  FUN = sum
)

cat("\nUndergraduate headcount by year + gender (province-wide):\n")
print(head(agg_ug_gender, 10))

# ==== 5. Generate plots (saved to out/ directory) ====

if (!dir.exists("out")) dir.create("out")

## Plot 1: Total headcount (all levels) over time
png("out/fig1_all_levels_total_by_year.png", width = 800, height = 600)
plot(
  agg_all$Year, agg_all$HEADCOUNT_num,
  type = "b",
  xlab = "Year (start of fiscal year)",
  ylab = "Total headcount (all levels, all genders)",
  main = "Ontario University Enrolment by Year (All Levels)"
)
dev.off()
cat("✅ Generated Plot 1: out/fig1_all_levels_total_by_year.png\n")

## Plot 2: Undergraduate total headcount over time
png("out/fig2_undergrad_total_by_year.png", width = 800, height = 600)
plot(
  agg_ug$Year, agg_ug$HEADCOUNT_num,
  type = "b",
  xlab = "Year",
  ylab = "Undergraduate headcount (all genders)",
  main = "Ontario Undergraduate Enrolment by Year"
)
dev.off()
cat("✅ Generated Plot 2: out/fig2_undergrad_total_by_year.png\n")

## Plot 3: Undergraduate gender proportion over time (province-wide, clear gender distinction)

# 1. Calculate proportions
totals <- aggregate(
  HEADCOUNT_num ~ Year,
  data = agg_ug_gender,
  FUN = sum
)
names(totals)[2] <- "Total"

agg_prop <- merge(agg_ug_gender, totals, by = "Year")
agg_prop$Prop <- agg_prop$HEADCOUNT_num / agg_prop$Total

agg_prop <- agg_prop[order(agg_prop$Year), ]
gender_levels <- unique(agg_prop$`Gender Group`)

# 2. Assign different colors/line types/point types for each gender
cols <- c(
  "Female"        = "red",
  "Male"          = "blue",
  "N/A or Another"= "darkgreen"
)
ltys <- c(
  "Female"        = 1,   # Solid line
  "Male"          = 2,   # Dashed line
  "N/A or Another"= 3    # Dotted line
)
pchs <- c(
  "Female"        = 16,  # Solid circle
  "Male"          = 17,  # Solid triangle
  "N/A or Another"= 15   # Solid square
)

png("out/fig3_undergrad_gender_proportion_by_year.png",
    width = 800, height = 600)

plot(
  agg_prop$Year, agg_prop$Prop,
  type = "n",
  xlab = "Year",
  ylab = "Proportion of undergraduate headcount",
  ylim = c(0, 1),
  main = "Ontario Undergraduate Enrolment by Gender (Proportion)"
)

for (g in gender_levels) {
  sub_g <- subset(agg_prop, `Gender Group` == g)
  lines(
    sub_g$Year, sub_g$Prop,
    type = "b",
    col  = cols[g],
    lty  = ltys[g],
    pch  = pchs[g]
  )
  # Optional: Label the last year of each line
  last <- nrow(sub_g)
  text(
    x = sub_g$Year[last] + 0.1,
    y = sub_g$Prop[last],
    labels = g,
    col = cols[g],
    cex = 0.8,
    pos = 4
  )
}

legend(
  "topleft",
  legend = gender_levels,
  col    = cols[gender_levels],
  lty    = ltys[gender_levels],
  pch    = pchs[gender_levels],
  bty    = "n"
)

dev.off()

cat("✅ Generated Plot 3 (color + labeled): out/fig3_undergrad_gender_proportion_by_year.png\n")


# ==== 6. Export modeling data df_model ====

df_model <- data.frame(
  Year        = agg_ug_gender$Year,
  GenderGroup = agg_ug_gender$`Gender Group`,
  Headcount   = agg_ug_gender$HEADCOUNT_num
)

write.csv(df_model, "out/eda_model_ready.csv", row.names = FALSE)

cat("\n✅ Exported modeling data to out/eda_model_ready.csv\n")
cat("   Future regression model can take the form: Headcount ~ Year + GenderGroup\n")

# ==== 1. Read modeling data from Step 2 ====

in_file <- "out/eda_model_ready.csv"

if (!file.exists(in_file)) {
  stop("Cannot find out/eda_model_ready.csv. Please run the EDA script first.")
}

df_model <- read.csv(in_file, stringsAsFactors = FALSE)

cat("✅ Loaded modeling data:", in_file, "\n")
str(df_model)

# Set column types
df_model$Year        <- as.numeric(df_model$Year)
df_model$GenderGroup <- factor(df_model$GenderGroup)

# Set a reference level (optional: use Female as baseline)
if ("Female" %in% levels(df_model$GenderGroup)) {
  df_model$GenderGroup <- relevel(df_model$GenderGroup, ref = "Female")
}

# ==== 2. Build linear regression model ====
# 模型解释：
#   Headcount = β0 + β1 * Year + β(性别) + 误差
#   Year 捕捉时间趋势，GenderGroup 捕捉不同性别的平均差异。

model_lm <- lm(Headcount ~ Year + GenderGroup, data = df_model)

cat("\n===== Regression Summary =====\n")
print(summary(model_lm))

# Save summary to a text file for report references
if (!dir.exists("out")) dir.create("out")

sink("out/regression_summary.txt")
cat("Linear regression model: Headcount ~ Year + GenderGroup\n\n")
print(summary(model_lm))
sink()

cat("✅ Saved regression summary to out/regression_summary.txt\n")

# ==== 3. Visualization 1: Data points + fitted lines (by gender) ====

# Calculate fitted values
df_model$Fitted <- fitted(model_lm)

# Set different colors/point types for GenderGroup (similar to Fig3)
gender_levels <- levels(df_model$GenderGroup)

cols <- c(
  "Female"        = "red",
  "Male"          = "blue",
  "N/A or Another"= "darkgreen"
)
pchs <- c(
  "Female"        = 16,
  "Male"          = 17,
  "N/A or Another"= 15
)

png("out/fig4_regression_fit_by_gender.png",
    width = 800, height = 600)

# Empty plot: X=Year, Y=Headcount
plot(
  df_model$Year, df_model$Headcount,
  type = "n",
  xlab = "Year",
  ylab = "Undergraduate headcount",
  main = "Regression Fit: Headcount ~ Year + GenderGroup"
)

# Plot actual points + fitted lines for each gender
for (g in gender_levels) {
  sub <- df_model[df_model$GenderGroup == g, ]
  # Sort by Year, plot points
  sub <- sub[order(sub$Year), ]
  points(sub$Year, sub$Headcount,
         col = cols[g], pch = pchs[g])
  # Fitted line
  lines(sub$Year, sub$Fitted,
        col = cols[g], lwd = 2)
}

legend(
  "topleft",
  legend = gender_levels,
  col    = cols[gender_levels],
  pch    = pchs[gender_levels],
  lwd    = 2,
  bty    = "n"
)

dev.off()

cat("✅ Generated plot: out/fig4_regression_fit_by_gender.png\n")

# ==== 4. Visualization 2: Standard regression diagnostic plots (residuals) ====

png("out/fig5_regression_diagnostics.png",
    width = 1000, height = 800)

par(mfrow = c(2, 2))
plot(model_lm)
par(mfrow = c(1, 1))

dev.off()

cat("✅ Generated plot: out/fig5_regression_diagnostics.png\n")

# ==== 5. Visualization 3: Residual distribution (histogram + QQ plot) ====

res <- resid(model_lm)

png("out/fig6_residual_hist_qq.png",
    width = 1000, height = 500)

par(mfrow = c(1, 2))

# 5.1 Residual histogram
hist(
  res,
  breaks = 10,
  main   = "Histogram of residuals",
  xlab   = "Residuals"
)

# 5.2 QQ plot
qqnorm(res, main = "Normal Q-Q plot of residuals")
qqline(res, col = "red")

par(mfrow = c(1, 1))
dev.off()

cat("✅ Generated plot: out/fig6_residual_hist_qq.png\n")

# ==== 6. Normality test: Shapiro-Wilk test ====
# 注意：样本量不是特别大时，这个检验才有意义；
# 在报告里要结合 QQ 图、直方图一起讨论。

shapiro_res <- shapiro.test(res)

cat("\n===== Shapiro-Wilk Normality Test Results =====\n")
print(shapiro_res)

sink("out/residual_normality_test.txt")
cat("Shapiro-Wilk Normality Test (Residuals Approx. Normal)\n\n")
print(shapiro_res)
sink()

cat("✅ Saved normality test results to out/residual_normality_test.txt\n")

cat("\nStep 3 Complete:\n",
    "- Built regression model Headcount ~ Year + GenderGroup\n",
    "- Generated regression fit and diagnostic plots\n",
    "- Checked residual normality (plots + Shapiro-Wilk)\n")

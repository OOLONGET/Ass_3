# Report on Enrollment Data Analysis

## Introduction
The dataset under analysis focuses on enrollment data, which provides insights into trends and patterns in educational participation. The analysis employs two primary methods:
1. **Exploratory Data Analysis (EDA)**: To summarize and visualize the data, identify patterns, and detect anomalies.
2. **Regression Analysis**: To model relationships between variables and assess the impact of predictors on the dependent variable.

## Methods
### Exploratory Data Analysis (EDA)
- Summary statistics were computed for both numeric and categorical variables.
- Visualizations, including histograms and boxplots, were generated to understand the distribution and variability of the data.
- Log transformations were applied to address skewness in numeric variables.

### Regression Analysis
- A linear regression model was fitted to the data, with diagnostics to assess model assumptions.
- Normality of residuals was evaluated using a QQ plot.
- Additional diagnostic plots were created to check for heteroscedasticity and influential points.

## Results

### Visualizations
- **Histograms and Boxplots**:
  - The dataset includes 92,352 observations across five variables: `Institution`, `Fiscal.Year`, `Study.Level`, `Program.Name`, and `HEADCOUNT`.
  - Visualizations (histograms and boxplots) revealed that the `HEADCOUNT` variable contains a mix of numeric and non-numeric values (e.g., `*`), which were addressed during preprocessing.
  - Log transformations were applied to `HEADCOUNT` to address skewness, improving the distribution for analysis.

### Regression Analysis
- **Regression Formula**: `HEADCOUNT ~ Institution + Fiscal.Year + Study.Level + Program.Name`
- **Model Summary**:
  - The regression model explains the variation in `HEADCOUNT` based on predictors such as `Institution`, `Fiscal.Year`, `Study.Level`, and `Program.Name`.
  - Significant predictors include:
    - Institutions like `Brock`, `Guelph`, `Metropolitan`, `Queen's`, `Toronto`, `Waterloo`, `Western`, and `York` (p-values < 0.05).
    - Fiscal years from `2019-2020` to `2023-2024` show increasing enrollment trends (p-values < 0.01).
    - `Study.Level` (Undergraduate) is a strong predictor (p-value < 2e-16).
  - The residuals show a median close to zero, but the range is wide, indicating variability in the data.

- **Normality of Residuals**:
  - The QQ plot (`out_Reg/qq_plot.png`) suggests deviations from normality, particularly in the tails, which may affect the reliability of p-values for some predictors.

## Discussion

### Trends in Enrollment Data
- Enrollment has increased significantly in recent fiscal years (`2019-2020` to `2023-2024`), with institutions like `Toronto` and `Western` showing the highest positive impact on `HEADCOUNT`.
- Undergraduate programs contribute significantly to enrollment numbers.

### Data Dredging
- The analysis was hypothesis-driven, focusing on predefined relationships between predictors and `HEADCOUNT`. This minimizes the risk of data dredging.
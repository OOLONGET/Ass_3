下面是按 A3 要求写好的 **英文报告正文**（你可以直接粘到 Word 里，再把图插进去当 Figure 1–6）：

---

**Title:**
Exploratory Data Analysis and Regression of Ontario University Enrolment (2012–2023)

---

### 1. Introduction

This report assumes the role of a data scientist working at the Ontario Ministry of Advanced Education. The goal is to understand recent trends in Ontario university enrolment using exploratory data analysis (EDA), visualization, and regression modelling, following the Assignment 3 instructions for COSC5926.

The dataset is the “University enrolment headcount, 2023–24” open data provided by the Government of Ontario. It contains annual fall-term enrolment headcounts by institution, study level, gender group, and other attributes. In this project, we focus on the **Gender** table and aggregate data at the **provincial** level (across all institutions). Our primary interest is in how **undergraduate enrolment** has evolved between fiscal years 2012–2013 and 2023–2024, and how this growth differs by gender group.

We use Excel and R together: Excel for initial inspection and R for data cleaning, visualization, regression analysis, and checking the normality assumption of residuals, as required by the assignment.

---

### 2. Methods

#### 2.1 Data preparation and EDA

The analysis begins with the **Gender** sheet of the Excel file. In R, we performed the following steps:

1. **Parsing the fiscal year.**
   The `Fiscal Year` field is of the form “2012-2013”. We extracted the first four digits and converted them to an integer `Year`, representing the start of the fiscal year.

2. **Cleaning the headcount variable.**
   The `HEADCOUNT` column was converted from text to numeric. Potential non-numeric values (such as symbols or empty cells) were removed. The cleaned column was stored as `HEADCOUNT_num`.

3. **Aggregating to provincial totals.**

   * For **all study levels**, we aggregated `HEADCOUNT_num` by `Year` to obtain the total provincial university headcount for each year.
   * For **undergraduate level only**, we filtered rows where `Study Level == "Undergraduate"` and then:

     * Aggregated by `Year` to obtain total undergraduate headcount for the province.
     * Aggregated by `Year` and `Gender Group` to obtain undergraduate headcounts by gender group.

4. **Constructing the modelling dataset.**
   For the regression analysis, we used the aggregated undergraduate dataset with one row per `(Year, GenderGroup)` combination and three variables:

   * `Year` (numeric),
   * `GenderGroup` (factor: *Female*, *Male*, *N/A or Another*),
   * `Headcount` (undergraduate headcount for that year and gender).

   This dataset was saved as `eda_model_ready.csv` and later re-used by the regression script.

During EDA, we produced several plots:

* **Figure 1.** Total Ontario university headcount (all levels and genders) by year.
* **Figure 2.** Total Ontario undergraduate headcount (all genders) by year.
* **Figure 3.** Proportion of undergraduate headcount by gender group over time (Female, Male, N/A or Another).

These plots provide an overview of the growth in enrolment and the stability or changes in the gender composition.

#### 2.2 Regression analysis

To quantify the trends observed in EDA, we fitted a **linear regression model** using R:

[
\text{Headcount} = \beta_0 + \beta_1 \cdot \text{Year} + \beta_2 \cdot \text{GenderGroup}*{\text{Male}} + \beta_3 \cdot \text{GenderGroup}*{\text{N/A/Another}} + \varepsilon,
]

where:

* `Headcount` is the provincial undergraduate enrolment for a given year and gender,
* `Year` is treated as a continuous predictor,
* `GenderGroup` is a categorical predictor with **Female** as the reference category.

We estimated the model using `lm()` in base R and extracted coefficient estimates, standard errors, and model fit statistics (R², F-test).

#### 2.3 Model visualization and diagnostics

We visualized the fitted model in two ways:

* **Figure 4.** For each gender group, we plotted observed undergraduate counts against year, and overlaid the corresponding fitted regression line. This helps us see both the growth trend and the differences between groups.
* **Figure 5.** Standard regression diagnostic plots from R (`plot(model_lm)`): residuals vs fitted, normal Q–Q plot, scale–location, and residuals vs leverage.
* **Figure 6.** A combined plot showing a histogram of the residuals and a Q–Q plot of residuals against the theoretical normal distribution.

We also formally tested the **normality of residuals** using the Shapiro–Wilk test in R.

---

### 3. Results

#### 3.1 Exploratory data analysis

**Overall university enrolment.**
Figure 1 shows that total university enrolment in Ontario (all levels and genders) increased steadily from approximately the low 420,000s in 2012 to over 510,000 by 2023. There are no sharp drops; the series is almost monotonic, indicating continuous growth in the sector.

**Undergraduate enrolment.**
Figure 2 focuses on undergraduate students only. The pattern is similar: enrolment rises from roughly 370,000 in 2012 to around 440,000 in 2023, with mild flattening around 2021–2022 and a noticeable increase in the most recent year. This suggests that most of the system-wide growth is driven by undergraduate students.

**Gender composition.**
Figure 3 presents the **proportion** of undergraduate headcount by gender group:

* **Female** students consistently account for about **55–57%** of undergraduate enrolment.
* **Male** students account for roughly **42–44%**.
* The **“N/A or Another”** category starts very close to zero and gradually increases to just above 2% in recent years.

Overall, the gender composition is relatively stable, with a slight decline in the male share and a small but noticeable increase in the N/A or Another category, reflecting a gradual recognition of gender diversity.

#### 3.2 Regression model

Table 1 (from `regression_summary.txt`) summarizes the fitted regression model `Headcount ~ Year + GenderGroup`.

Key findings include:

* The **intercept** is −4,313,802 (p < 0.001), which is not directly interpretable by itself but works together with the year coefficient to produce realistic values in the observed range.
* The **Year coefficient** is approximately **2,248.7** (SE ≈ 178.7, p < 0.001). This means that, holding gender constant, provincial undergraduate enrolment increases on average by about **2,249 students per year**.
* Relative to **Female** students (the reference group), the **Male** coefficient is about **−48,229** (p < 0.001). This indicates that, for the same year, the male headcount is on average about 48,000 lower than the female headcount at the provincial level.
* The **N/A or Another** coefficient is about **−220,026** (p < 0.001), reflecting the much smaller size of this group compared with female students.

The model has an **R² of 0.9987** (adjusted R² 0.9985), and the overall F-statistic is extremely large with p < 2.2×10⁻¹⁶, indicating that the model explains almost all of the variation in the aggregated headcounts. While this high R² is not surprising given that the data are smooth yearly aggregates, it confirms that a simple linear trend plus gender effects captures the main structure of the data.

Figure 4 visually corroborates these results: each gender group shows an approximately linear upward trend over time, with the female series highest, the male series lower, and the N/A or Another group much lower but also increasing.

#### 3.3 Normality of residuals

The histogram of residuals in Figure 6 appears roughly symmetric, with most residuals clustered around zero and a few larger positive values. The Q–Q plot shows points close to the reference line, with mild deviations in the upper tail.

The **Shapiro–Wilk test** yields W = 0.958 and p = 0.1979, which is well above the usual 0.05 threshold.  Therefore, we do **not** reject the null hypothesis that the residuals are normally distributed. Combined with the visual diagnostics, this suggests that the normality assumption for the residuals is reasonably satisfied in this model.

The residuals-versus-fitted plot (Figure 5) shows no strong non-linear pattern, although there is some curvature and variation in spread at extreme fitted values. The leverage plot indicates that no single observation exerts extreme influence on the fitted model.

---

### 4. Discussion

The analysis provides several insights into Ontario university enrolment between 2012 and 2023:

1. **Sustained growth in enrolments.**
   Both overall and undergraduate enrolments show a steady upward trajectory. This suggests a continuing demand for university education in Ontario and has implications for long-term planning of teaching resources, physical capacity, and student services.

2. **Stable but imbalanced gender composition.**
   Female students consistently form the majority of undergraduate enrolments, around 55–57%, while males represent 42–44%. The N/A or Another category, while still small, increases slowly over time, reflecting evolving practices in gender identification and reporting. These patterns may motivate targeted outreach or support programs to address gender-based disparities in some fields or institutions.

3. **Adequacy of the simple linear model.**
   The linear regression with Year and GenderGroup explains nearly all of the variation in aggregated headcounts and passes the residual normality check reasonably well. Given the small sample size (a modest number of years) and the smoothness of provincial aggregates, a simple linear trend model is appropriate for this assignment. However, in a more advanced setting, one might consider time-series models or incorporate additional predictors such as immigration, tuition policy changes, or economic indicators.

4. **Limitations and potential biases.**
   The analysis is based on **aggregated provincial data**, which hides institution-level and program-level differences. It also treats Year as a purely linear effect, which may not capture more complex dynamics (e.g., sudden changes due to policy shifts or the COVID-19 pandemic). Furthermore, the counts represent fall enrolment only and may not reflect retention or graduation outcomes.

5. **Data dredging considerations.**
   In this project, we first used domain knowledge and the assignment instructions to choose a clear modelling question: explaining **provincial undergraduate headcount** using **Year** and **GenderGroup**. EDA was then used to verify that these variables exhibit interpretable patterns rather than to search through many combinations of variables or models. Thus, the risk of severe “data dredging” is limited, although we acknowledge that using the same dataset for both EDA and modelling can still introduce mild data snooping—a common constraint in small educational assignments.

---

### 5. Conclusion

Using Ontario’s provincial university enrolment data, we applied EDA, visualization, and linear regression to study undergraduate enrolment trends from 2012 to 2023. The results show steady growth in enrolment, a persistent female majority in the student population, and a small but growing share of students identifying as N/A or Another gender. A simple regression model with Year and GenderGroup captures these patterns well and satisfies the normality assumption for residuals.

This exercise demonstrates how basic statistical tools in R can be used to turn open government data into interpretable insights that support policy discussions on higher education planning and equity.

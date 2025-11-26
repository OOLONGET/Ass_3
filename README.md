## 1. 项目概览

本项目基于安大略省政府公开数据集 *“University enrolment headcount, 2023–24”*，对 2012–2023 年间安大略省大学入学人数进行探索性数据分析（EDA）和线性回归建模。

当前分析聚焦于：

* 省级整体入学人数随时间的变化（所有层次）
* 本科（Undergraduate）入学人数的变化
* 本科阶段按性别（Gender Group）的构成与变化
* 回归模型：
  [
  \text{Headcount} \sim \text{Year} + \text{GenderGroup}
  ]

---

## 2. 文件与目录结构

项目根目录下主要文件和文件夹说明如下（只列关键部分）：

* `university_enrolment_headcount_2023-24.xlsx`

  * 原始 Excel 数据，来自安大略省高等教育厅开放数据，**请勿修改**。
  * 实际使用的是其中的 `Gender` 工作表。

* `eda.R`

  * EDA 与数据准备脚本（Step 2）。
  * 负责：

    * 读入 `Gender` sheet
    * 清洗数据（Fiscal Year → Year，HEADCOUNT → 数值）
    * 省级聚合（按 Year / Study Level / Gender Group）
    * 生成图 Fig 1–3
    * 导出建模数据 `out/eda_model_ready.csv`

* `regression.R`

  * 回归分析与诊断脚本（Step 3）。
  * 负责：

    * 读入 `out/eda_model_ready.csv`
    * 拟合线性回归模型 `Headcount ~ Year + GenderGroup`
    * 生成回归相关图（fig 4–6）
    * 进行残差正态性检验，并输出结果文件。

* `out/` 目录（由脚本自动创建）

  * `fig1_all_levels_total_by_year.png`
  * `fig2_undergrad_total_by_year.png`
  * `fig3_undergrad_gender_proportion_by_year.png`
  * `fig4_regression_fit_by_gender.png`
  * `fig5_regression_diagnostics.png`
  * `fig6_residual_hist_qq.png`
  * `eda_model_ready.csv` – 整理好的建模数据
  * `regression_summary.txt` – 回归模型 summary 输出
  * `residual_normality_test.txt` – Shapiro-Wilk 残差正态性检验结果

* `final_report.docx`（如果你已经生成）

  * 按 A3 要求写好的最终报告，包含图表与结果解释。

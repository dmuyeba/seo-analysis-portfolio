# SEO Performance Analytics & Predictive Modelling

An end-to-end SEO analytics project combining SQL, Python and R to analyse organic search performance and identify optimisation opportunities, identify optimisation opportunities, and model click behaviour using machine learning techniques.

The project follows a full analytics workflow including:

* data cleaning and preprocessing,
* exploratory data analysis,
* segmentation and clustering,
* predictive modelling,
* and statistical inference.

---

## Project Overview

This repository explores website SEO performance using page-level search and content metrics.

The analysis investigates questions such as:

* Which pages underperform despite strong visibility?
* What characteristics define high-performing pages?
* Are there identifiable "quick-win" optimisation opportunities?
* Which features most strongly influence click performance?
* Can machine learning predict organic search clicks?

The project combines technical SEO concepts with data science and statistical analysis techniques.

---

## Repository Structure

```text
├── sql/
│   ├── sql_data_cleaning_and_queries.ipynb
│   └── report/
│
├── python_eda/                  # In Progress
├── python_clustering/           # In Progress
├── python_prediction/           # In Progress
├── r_statistical_analysis/      # In Progress
│
├── data/
├── tables/
└── README.md
```

---

## Project Stages

### 1. Data Cleaning, Views & Queries (SQL)

Current notebook included in repository.

This stage focuses on:

* cleaning and preprocessing raw SEO performance data,
* type conversion and handling missing values,
* creation of reusable SQL views,
* page-level feature engineering,
* SEO issue classification,
* analytical querying for business insights.

Key outputs include:

* quick-win opportunity identification,
* CTR analysis,
* page segmentation,
* indexing/performance diagnostics,
* technical SEO issue aggregation.

---

### 2. Exploratory Data Analysis (Python) *(In Progress)*

Planned analyses include:

* data profiling,
* feature distributions,
* outlier analysis,
* correlation analysis,
* segment-level comparisons,
* visualisation of SEO performance trends.

Libraries:

* Pandas
* NumPy
* Matplotlib
* Seaborn

---

### 3. Clustering & Segmentation (Python) *(In Progress)*

This stage will apply unsupervised learning techniques to identify page groups and optimisation opportunities.

Planned methods include:

* K-Means clustering,
* feature scaling,
* cluster interpretation,
* quick-win segmentation,
* performance archetype analysis.

---

### 4. Predictive Modelling (Python) *(In Progress)*

This stage aims to predict organic search clicks using machine learning models.

Planned work includes:

* feature engineering,
* train/test evaluation,
* XGBoost regression modelling,
* feature importance analysis,
* model performance evaluation.

Potential prediction targets:

* clicks,
* CTR,
* visibility opportunity.

---

### 5. Statistical Analysis (R) *(In Progress)*

This stage will apply inferential statistical techniques to validate findings from the exploratory and predictive analyses.

Planned analyses include:

* hypothesis testing,
* confidence intervals,
* correlation significance,
* regression diagnostics,
* conclusion validation.

Libraries:

* tidyverse
* ggplot2
* infer
* broom

---

## Technologies Used

### SQL

* SQLite
* Jupyter SQL Magic

### Python

* Pandas
* NumPy
* Scikit-learn
* XGBoost
* Matplotlib
* Seaborn

### R

* tidyverse
* ggplot2

---

## Example Research Questions

* What characteristics are associated with low CTR pages?
* Which technical SEO issues correlate with weak performance?
* Are certain page segments more likely to underperform?
* Which pages represent the highest optimisation potential?
* Can organic click performance be predicted from page features?

---

## Report

A written analytical report accompanies the SQL analysis notebook and summarises:

* methodology,
* key findings,
* business implications,
* limitations,
* recommendations.

---

## Status

Current status:

* [x] SQL cleaning and analytical querying
* [ ] Python EDA
* [ ] Clustering analysis
* [ ] Predictive modelling
* [ ] Statistical analysis in R

---

## Author
Daniel Muyeba, recent MSc Data Science student with over 5 years of professional experience in SEO in agency and in-house.

---

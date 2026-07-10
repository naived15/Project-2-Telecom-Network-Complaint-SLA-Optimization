# Telecom Network Complaint & SLA Optimization

## Project Overview

This project analyzes 105,250 telecom customer complaints to identify SLA breach drivers, engineer workload imbalances, recurring fault hotspots, and operational inefficiencies. The solution combines MySQL, Python, and Power BI to transform raw complaint data into actionable business insights and executive-level reporting.

---

## Business Problem

Telecom operators often discover SLA breaches only after monthly reporting cycles, leading to delayed corrective actions, customer dissatisfaction, and increased operational costs.

This project answers key business questions:

- Which complaint categories contribute most to SLA breaches?
- Which regions have the highest breach rates?
- Are engineers being utilized efficiently?
- Which fault locations generate recurring complaints?
- What factors increase breach risk?

---

## Project Objectives

- Analyze SLA compliance across complaint categories and regions
- Measure Mean Time to Resolution (MTTR)
- Detect recurring network fault hotspots
- Evaluate engineer utilization and skill mismatches
- Build a predictive breach-risk model
- Create an interactive executive dashboard

---

## Dataset Information

| Metric | Value |
|----------|----------|
| Total Complaints | 105,250 |
| Customers | 45,080 |
| Engineers | 240 |
| SLA Target Records | 16 |
| Database Tables | 5 |
| Data Quality Issues Fixed | 13 |

### Source Tables

- Customers
- Complaints
- Engineers
- Assignments
- SLA Targets

---

## Technology Stack

### Database
- MySQL
- Relational Data Modeling
- SQL Views
- Indexing

### Programming
- Python
- Pandas
- NumPy
- Scikit-Learn
- Matplotlib

### Visualization
- Power BI
- DAX

---

## Project Architecture

```text
Raw CSV Files
      │
      ▼
MySQL Staging Tables
      │
      ▼
Data Cleaning & Validation
      │
      ▼
Normalized Relational Database
      │
      ▼
SQL Analysis
      │
      ▼
Python Analytics
      │
      ▼
Power BI Dashboard
```

---

## Data Cleaning & Preparation

A staging-table ETL approach was used to clean and standardize raw telecom data.

### Issues Resolved

- Duplicate complaint records
- Duplicate assignment records
- Text formatting inconsistencies
- Region naming inconsistencies
- Severity value standardization
- Missing severity values
- Missing customer IDs
- Missing fault locations
- Invalid timestamps
- Duration outliers
- Duplicate customer master records
- Mixed date formats

Total Data Quality Fixes: **13**

---

## Database Design

### Final Tables

- customers
- complaints
- engineers
- assignments
- sla_targets

### Views Created

- vw_kpi_summary
- vw_engineer_utilisation
- vw_monthly_trend

---

## SQL Analysis

Performed 12+ analytical SQL queries including:

### KPI Analysis
- Total Complaints
- SLA Compliance %
- Average MTTR

### Operational Analysis
- SLA Breach % by Complaint Type
- SLA Breach % by Region
- MTTR by Engineer
- Engineer Utilization Analysis
- Monthly Complaint Trends

### Root Cause Analysis
- Recurring Fault Hotspots
- Repeat Complaints
- Severity Analysis
- Skill Mismatch Analysis

### SQL Concepts Used
- JOINs
- Window Functions
- Self JOINs
- Aggregations
- CASE Statements
- Views
- Indexing

---

## Python Analytics

### Root Cause Detection
Implemented rolling 30-day analysis to identify recurring network fault locations.

### Engineer Utilization
Calculated engineer workload relative to regional averages using a Utilization Index.

### Repeat Complaint Detection
Identified customers raising the same complaint type within a 90-day period.

### Skill Mismatch Analysis
Measured assignment inefficiencies where engineer skill type differed from complaint type.

### Breach Risk Prediction
Developed a Logistic Regression model using:
- Complaint Type
- Severity
- Region

to predict SLA breach probability.

---

## Power BI Dashboard

### KPIs

- Total Complaints
- Average MTTR (Hours)
- SLA Compliance %
- Maximum Utilization Index
- Skill Mismatch %

### Visualizations

- SLA Breach % by Region
- SLA Breach % by Severity
- Complaint Mix by Type
- Recurring Fault Hotspots
- Monthly Complaint Trend
- Engineer Utilization Analysis

### Interactive Filters

- Region
- Severity
- Complaint Type
- Date Range

---

## Dashboard Preview

![Dashboard](dashboard.png)

---

## Key Insights

- SLA Compliance achieved: **78.54%**
- Average MTTR: **26.32 Hours**
- Skill Mismatch Rate: **14.6%**
- Network complaints generated significantly higher SLA breach rates.
- Certain regions experienced consistently higher breach percentages due to workload imbalance.
- Recurring fault hotspots contributed disproportionately to network-related complaints.

---

## Business Impact

This solution helps telecom operations teams:

- Reduce SLA violations
- Improve complaint resolution efficiency
- Optimize engineer allocation
- Identify recurring infrastructure failures
- Improve customer satisfaction
- Support proactive operational decision-making

---

## Project Deliverables

- MySQL Database
- SQL Analysis Scripts
- Python Analytics Notebook
- Power BI Dashboard
- BRD Documentation
- FRD Documentation

---

## Repository Structure

```text
Telecom-SLA-Optimization/
│
├── Telecom_SLA_Analysis.ipynb
├── Telecom_SQL_Queries.sql
├── Telecom_SLA_Dashboard.pbix
├── dashboard.png
├── README.md
│
└── Dataset/
    ├── customers.csv
    ├── complaints.csv
    ├── assignments.csv
    ├── engineers.csv
    └── sla_targets.csv
```

---

## Author

**Naived Chourasia**

MBA Business Analytics

Skills: SQL | Python | Power BI | Data Analysis | Business Analysis

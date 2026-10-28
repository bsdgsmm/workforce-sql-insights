# Workforce SQL Insights

A SQL-based workforce analytics project exploring headcount, salary distributions, hiring trends, employee tenure, and workforce turnover.

The project models a fictional mid-sized company with ten years of employment history (January 2016 to December 2025) and answers common people-analytics questions with plain, reproducible SQL running on DuckDB. Every analysis is a named SQL view, every view is executed by the test suite, and the key metrics are reconciled against independent calculations.

## Contents

- [Business Problem and Objectives](#business-problem-and-objectives)
- [Technology Stack](#technology-stack)
- [Dataset](#dataset)
- [Data Dictionary](#data-dictionary)
- [Schema and Relationships](#schema-and-relationships)
- [Repository Structure](#repository-structure)
- [Setup](#setup)
- [Running the Analysis](#running-the-analysis)
- [Analyses](#analyses)
- [Metric Definitions](#metric-definitions)
- [SQL Techniques Demonstrated](#sql-techniques-demonstrated)
- [Findings from the Sample Dataset](#findings-from-the-sample-dataset)
- [Testing](#testing)
- [Limitations and Future Improvements](#limitations-and-future-improvements)

## Business Problem and Objectives

HR and finance teams regularly need consistent answers to questions such as:

- How many people work here today, and where?
- How has the workforce grown, and how does hiring vary by month and department?
- How are salaries distributed across departments, job titles, and levels?
- How long do employees stay, and how many new hires remain after their first year?
- What is the turnover rate, how has it changed, and which departments see the most separations?

The objectives of this project are to:

1. Model workforce data relationally with enforced keys and constraints.
2. Define each metric explicitly, including the reporting date, numerator, and denominator.
3. Reconstruct historical headcount from hire and termination dates instead of relying on today's headcount.
4. Keep every query reproducible and verified by automated tests.

## Technology Stack

| Component | Purpose |
| --- | --- |
| [DuckDB](https://duckdb.org/) | Embedded SQL engine; no server required |
| SQL | All analytical logic |
| Python 3 (tested with 3.12) | Synthetic data generation and query runner |
| [pytest](https://docs.pytest.org/) | Metric validation and regression tests |

All tools are free and open source.

## Dataset

The dataset in [`data/sample`](data/sample) is **entirely synthetic**. It was produced by [`scripts/generate_sample_data.py`](scripts/generate_sample_data.py) using a fixed random seed (`20240101`), so regenerating it yields byte-identical files. It contains no real people, names, or personal information, and the results below describe this synthetic company only.

| File | Rows | Grain |
| --- | ---: | --- |
| `departments.csv` | 8 | One row per department |
| `jobs.csv` | 33 | One row per job title |
| `locations.csv` | 6 | One row per work location |
| `employees.csv` | 1,186 | One row per employment record (employee) |

How the generator works:

- Monthly hiring volume grows over time and follows a seasonal pattern.
- Each hire is assigned a department, job title, location, and employment type using fixed weights.
- Length of employment is drawn from an exponential distribution whose rate depends on the department and employment type.
- If the drawn separation date falls on or before the reporting date (2025-12-31), the employee is `Terminated` and receives a termination date and type; otherwise the employee is `Active` with no termination details.
- Salary is drawn within the salary band of the employee's job title and rounded to the nearest 100.

Assumptions:

- `annual_salary` is the annualized, full-time-equivalent base salary in USD. For terminated employees it is the salary at departure. Salary history is not modeled.
- Each employee holds one job for the whole employment period; promotions and transfers are not modeled.
- Rehires are not modeled; each `employee_id` represents one continuous employment period.
- The reporting date is fixed at **2025-12-31** through the `as_of_date()` macro.

## Data Dictionary

### `employees`

| Column | Type | Description |
| --- | --- | --- |
| `employee_id` | INTEGER | Primary key, unique per employee |
| `job_id` | INTEGER | Foreign key to `jobs` |
| `location_id` | INTEGER | Foreign key to `locations` |
| `employment_type` | VARCHAR | `Full-time`, `Part-time`, or `Contract` |
| `hire_date` | DATE | First day of employment |
| `termination_date` | DATE | Effective separation date; `NULL` for active employees |
| `employment_status` | VARCHAR | `Active` or `Terminated` as of the reporting date |
| `termination_type` | VARCHAR | `Voluntary` or `Involuntary`; `NULL` for active employees |
| `annual_salary` | INTEGER | Annualized base salary in USD |

### `jobs`

| Column | Type | Description |
| --- | --- | --- |
| `job_id` | INTEGER | Primary key |
| `job_title` | VARCHAR | Unique job title |
| `department_id` | INTEGER | Foreign key to `departments` |
| `job_level` | INTEGER | 1 (entry) to 4 (manager) |
| `salary_band_min` | INTEGER | Lower bound of the salary band |
| `salary_band_max` | INTEGER | Upper bound of the salary band |

### `departments`

| Column | Type | Description |
| --- | --- | --- |
| `department_id` | INTEGER | Primary key |
| `department_name` | VARCHAR | Unique department name |

### `locations`

| Column | Type | Description |
| --- | --- | --- |
| `location_id` | INTEGER | Primary key |
| `location_name` | VARCHAR | City, or `Remote` |
| `country` | VARCHAR | Country of the location |
| `region` | VARCHAR | `North America`, `Europe`, or `Remote` |

### Helper objects

| Object | Description |
| --- | --- |
| `as_of_date()` | Macro returning the reporting date, `2025-12-31` |
| `employee_details` | View joining employees to jobs, departments, and locations |
| `reporting_months` | View with one row per calendar month from the first hire month to the reporting month |

## Schema and Relationships

```text
departments 1 ──< jobs 1 ──< employees >── 1 locations
```

- A department has many job titles; each job title belongs to exactly one department.
- A job title has many employees; each employee holds exactly one job title.
- A location has many employees; each employee has exactly one location.

Primary keys, foreign keys, `NOT NULL`, and `CHECK` constraints are declared in [`sql/00_load_data.sql`](sql/00_load_data.sql), so loading invalid keys or values fails immediately.

## Repository Structure

```text
workforce-sql-insights/
├── data/sample/                  Synthetic CSV files
├── scripts/
│   ├── generate_sample_data.py   Deterministic dataset generator
│   └── run_analysis.py           Loads the data and runs every SQL file
├── sql/
│   ├── 00_load_data.sql          Schema, constraints, data load, helper views
│   ├── 01_workforce_overview.sql
│   ├── 02_headcount_analysis.sql
│   ├── 03_salary_analysis.sql
│   ├── 04_hiring_and_tenure.sql
│   ├── 05_turnover_analysis.sql
│   ├── 06_advanced_sql.sql
│   └── 07_data_quality.sql
├── tests/                        pytest suite
├── requirements.txt
└── README.md
```

## Setup

```bash
git clone https://github.com/bsdgsmm/workforce-sql-insights.git
cd workforce-sql-insights
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

On Windows, activate the environment with `.venv\Scripts\activate`.

## Running the Analysis

Regenerate the sample dataset (optional, the CSV files are already committed and the output is identical):

```bash
python scripts/generate_sample_data.py
```

Load the data and execute every analysis file, exporting each view to CSV:

```bash
python scripts/run_analysis.py --output-dir output
```

Results are written to `output/<sql file name>/<view name>.csv`, for example `output/05_turnover_analysis/turnover_annual.csv`.

To build a persistent DuckDB database file that can be explored with any DuckDB client:

```bash
python scripts/run_analysis.py --database workforce.duckdb
```

The database then contains every table and view, so it can be queried directly:

```python
import duckdb

con = duckdb.connect("workforce.duckdb")
con.sql("SELECT * FROM turnover_annual").show()
```

Every analysis file depends only on `00_load_data.sql`, so any single file can be executed on its own after the load script. Run commands from the repository root, because the load script reads the CSV files with relative paths.

## Analyses

Each SQL file creates a set of views. The runner exports all 57 analysis views.

| File | Views | Questions answered |
| --- | --- | --- |
| [`01_workforce_overview.sql`](sql/01_workforce_overview.sql) | `overview_*` | Record counts, filtered employee lists, department payroll statistics, `HAVING` thresholds, `CASE` segments, `NULL` labeling |
| [`02_headcount_analysis.sql`](sql/02_headcount_analysis.sql) | `headcount_*` | Current headcount; distribution by department, job title, employment type, and location; month-end and year-end headcount history |
| [`03_salary_analysis.sql`](sql/03_salary_analysis.sql) | `salary_*` | Average, median, and quartiles by department; job title ranges and compa-ratios; salary bands; rankings; department comparisons with sample-size and job-level context |
| [`04_hiring_and_tenure.sql`](sql/04_hiring_and_tenure.sql) | `hiring_*`, `employee_tenure`, `tenure_*`, `longest_serving_active_employees` | Monthly, yearly, seasonal, and departmental hiring; tenure per employee; tenure bands; hiring cohort retention |
| [`05_turnover_analysis.sql`](sql/05_turnover_analysis.sql) | `turnover_*`, `hires_vs_terminations_by_year`, `separations_by_tenure_at_exit` | Monthly and annual turnover, voluntary and involuntary rates, department and employment type turnover, hires versus terminations |
| [`06_advanced_sql.sql`](sql/06_advanced_sql.sql) | `advanced_*` | Quarter-over-quarter and year-over-year comparisons, running totals, rankings, hire intervals, correlated subqueries, pivots |
| [`07_data_quality.sql`](sql/07_data_quality.sql) | `data_quality_*` | Uniqueness, completeness, referential integrity, date validity, status consistency, and value validity checks |

## Metric Definitions

All dates are calendar dates without time components. All periods are calendar months or calendar years.

| Metric | Definition |
| --- | --- |
| **Reporting date** | `2025-12-31`, returned by `as_of_date()` |
| **Active on date _d_** | `hire_date <= d` and (`termination_date IS NULL` or `termination_date > d`). An employee is no longer counted on their termination date. |
| **Current headcount** | Employees active on the reporting date. This equals the number of `Active` records, which is verified by a test. |
| **Month-end headcount** | Employees active on the last day of the month, reconstructed from hire and termination dates. |
| **Opening headcount** | Employees active on the day before the month starts (equals the previous month-end headcount). |
| **Separation** | An employee whose `termination_date` falls within the period. Employees without a termination date are never counted as separations. |
| **Monthly turnover rate** | Separations in the month ÷ ((opening headcount + closing headcount) ÷ 2) × 100 |
| **Annual turnover rate** | Separations in the calendar year ÷ average of the twelve month-end headcounts in that year × 100 |
| **Voluntary / involuntary turnover rate** | Same denominator as the annual rate, with only voluntary or involuntary separations in the numerator |
| **Recent annualized turnover** | Separations from 2023-01-01 to 2025-12-31 ÷ average month-end headcount over those 36 months ÷ 3 × 100 |
| **Tenure** | Days from `hire_date` to `termination_date` for former employees, or to the reporting date for active employees. Tenure in years = days ÷ 365.25. |
| **One-year retention** | Among hires whose first anniversary (hire date + 365 days) is on or before the reporting date, the share still employed after that anniversary. Hires without a full year of observation are excluded from the denominator. |
| **Compa-ratio** | `annual_salary` ÷ midpoint of the job's salary band |
| **Salary statistics** | Calculated on active employees only. Medians use `MEDIAN`, quartiles use `QUANTILE_CONT`. |

The 2016 turnover rate is calculated on a workforce that grew from zero during the year, so its small denominator makes it less comparable to later years.

## SQL Techniques Demonstrated

| Technique | Example |
| --- | --- |
| Filtering, sorting, aggregation | `overview_department_salary_statistics` |
| `GROUP BY` with `HAVING` | `overview_departments_with_over_50_active`, `advanced_departments_above_company_separation_share` |
| `CASE` expressions | `salary_band_distribution`, `employee_tenure`, `overview_employee_status_labels` |
| `NULL` handling (`COALESCE`, `NULLIF`, `COUNT(column)`) | `overview_employee_status_labels`, `hiring_cohort_comparison` |
| Joins across four tables | `employee_details` |
| Common table expressions | `salary_department_vs_company`, `hires_vs_terminations_by_year` |
| Correlated and `EXISTS` subqueries | `advanced_above_department_average_salary`, `advanced_jobs_without_active_employees` |
| `ROW_NUMBER`, `RANK`, `DENSE_RANK`, `PERCENT_RANK`, `NTILE` | `advanced_top_hiring_department_by_year`, `salary_ranking_within_department` |
| `LAG` and `LEAD` | `advanced_quarterly_hiring_comparison`, `advanced_month_over_month_headcount`, `advanced_days_between_department_hires` |
| Running totals and moving averages | `advanced_running_hires_by_department`, `turnover_annual_trend` |
| Conditional aggregation (`FILTER`, `SUM(CASE ...)`) | `headcount_employment_type_by_department`, `advanced_region_employment_type_matrix` |
| Date series and point-in-time logic | `reporting_months`, `headcount_month_end`, `turnover_monthly` |
| Data quality checks | `data_quality_checks`, `data_quality_potential_duplicate_records` |

## Findings from the Sample Dataset

The figures below were produced by the queries in this repository against the committed synthetic dataset. They describe a fictional company and are not real-world benchmarks.

**Headcount**

- The dataset holds 1,186 employment records: 574 active employees and 612 former employees as of 2025-12-31.
- Engineering is the largest department with 164 active employees (28.6% of headcount); Human Resources is the smallest with 33 (5.7%).
- Full-time employees make up 88.9% of active headcount, part-time 6.3%, and contract 4.9%.
- Year-end headcount grew every year, from 77 at the end of 2016 to 574 at the end of 2025.

**Salary**

- The company-wide median salary of active employees is 76,750 USD.
- Department medians range from 46,200 USD in Customer Support to 112,300 USD in Product.
- Department differences largely reflect the mix of job titles and salary bands in each department. `salary_by_department_and_job_level` compares departments within the same job level, and `salary_department_vs_company` reports the average job level alongside each median. No conclusions about pay equity are drawn, as the data does not support that analysis.

**Hiring and tenure**

- Annual hires ranged from 91 in 2016 to 155 in 2025.
- January and September are the busiest hiring months (134 hires each across the ten years); December is the quietest (64).
- Median tenure of active employees by department ranges from 1.38 years in Customer Support to 3.98 years in Product.
- One-year retention for fully observable cohorts (2016 to 2024) ranges from 74.7% (2016 cohort) to 84.7% (2023 cohort).

**Turnover**

- Annual turnover was 17.3% in 2025, compared with 18.3% in 2024 and 19.0% in 2023.
- The highest annual rate after the 2016 ramp-up year was 24.7% in 2021.
- Over 2023 to 2025, annualized turnover was highest in Customer Support (36.7%) and Sales (26.6%) and lowest in Product (10.2%).
- Contract employees had an annualized turnover rate of 41.0% over 2023 to 2025, compared with 16.6% for full-time employees.
- 34.3% of all separations happened within the first year of employment.

These patterns are a direct consequence of the generator's department and employment type parameters. They demonstrate that the SQL recovers the structure in the data; they do not explain why employees leave.

**Data quality**

- All 15 checks in `data_quality_checks` pass on the sample dataset, and a test confirms that the checks detect deliberately injected errors.

## Testing

```bash
python -m pytest
```

The suite contains 54 tests and covers:

- Deterministic regeneration of the dataset.
- Primary key uniqueness, status and termination consistency, date validity, and salary band compliance.
- Reconciliation of every breakdown with its total (headcount, hires, separations, payroll).
- Month-end headcount roll-forward (`previous + hires - terminations`) and point-in-time recalculation.
- An independent Python recalculation of the 2024 annual turnover rate and of department medians and averages.
- Correct offsets for `LAG`, year-over-year comparisons, and running totals.
- Execution of each SQL file on its own and export of every view by the runner.
- Absence of comments in SQL files.

## Limitations and Future Improvements

Limitations:

- The data is synthetic. Distributions follow simple parametric assumptions and do not reflect any real organization or labor market.
- Salaries are a single current or final value; salary growth, promotions, and transfers are not modeled.
- Rehires, leaves of absence, and multiple concurrent positions are not represented.
- Salaries are expressed in USD for all locations without currency or cost-of-living adjustments.
- Small groups, such as level 4 positions within a single department, produce unstable statistics; the views flag small samples instead of suppressing them.

Possible improvements:

- Add a job history table to analyze promotions, internal mobility, and salary progression.
- Add survival analysis (for example, Kaplan-Meier retention curves) to handle censored tenure more rigorously.
- Add a configurable reporting date and rolling twelve-month turnover.
- Add visual dashboards on top of the exported views.

CREATE OR REPLACE VIEW salary_by_department AS
SELECT
    department_name,
    COUNT(*) AS active_employees,
    ROUND(AVG(annual_salary), 0) AS average_salary,
    MEDIAN(annual_salary) AS median_salary,
    QUANTILE_CONT(annual_salary, 0.25) AS p25_salary,
    QUANTILE_CONT(annual_salary, 0.75) AS p75_salary,
    ROUND(STDDEV_SAMP(annual_salary), 0) AS salary_standard_deviation,
    MIN(annual_salary) AS minimum_salary,
    MAX(annual_salary) AS maximum_salary,
    CASE WHEN COUNT(*) < 30 THEN 'Small sample' ELSE 'Adequate sample' END AS sample_size_note
FROM employee_details
WHERE employment_status = 'Active'
GROUP BY department_name
ORDER BY median_salary DESC;

CREATE OR REPLACE VIEW salary_range_by_job_title AS
SELECT
    department_name,
    job_title,
    job_level,
    COUNT(*) AS active_employees,
    MIN(annual_salary) AS minimum_salary,
    MEDIAN(annual_salary) AS median_salary,
    MAX(annual_salary) AS maximum_salary,
    MAX(annual_salary) - MIN(annual_salary) AS observed_range,
    ANY_VALUE(salary_band_min) AS salary_band_min,
    ANY_VALUE(salary_band_max) AS salary_band_max,
    ROUND(AVG(annual_salary / ((salary_band_min + salary_band_max) / 2.0)), 3) AS average_compa_ratio
FROM employee_details
WHERE employment_status = 'Active'
GROUP BY department_name, job_title, job_level
ORDER BY department_name, job_level, job_title;

CREATE OR REPLACE VIEW salary_band_distribution AS
WITH banded AS (
    SELECT
        CASE
            WHEN annual_salary < 50000 THEN '1. Under 50k'
            WHEN annual_salary < 75000 THEN '2. 50k to 75k'
            WHEN annual_salary < 100000 THEN '3. 75k to 100k'
            WHEN annual_salary < 125000 THEN '4. 100k to 125k'
            WHEN annual_salary < 150000 THEN '5. 125k to 150k'
            ELSE '6. 150k and above'
        END AS salary_band
    FROM employees
    WHERE employment_status = 'Active'
)
SELECT
    salary_band,
    COUNT(*) AS active_employees,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS share_pct,
    SUM(COUNT(*)) OVER (ORDER BY salary_band) AS cumulative_employees
FROM banded
GROUP BY salary_band
ORDER BY salary_band;

CREATE OR REPLACE VIEW salary_ranking_within_department AS
SELECT
    employee_id,
    department_name,
    job_title,
    annual_salary,
    RANK() OVER (PARTITION BY department_name ORDER BY annual_salary DESC) AS department_rank,
    DENSE_RANK() OVER (PARTITION BY department_name ORDER BY annual_salary DESC) AS department_dense_rank,
    ROUND(PERCENT_RANK() OVER (PARTITION BY department_name ORDER BY annual_salary), 3) AS department_percent_rank,
    NTILE(4) OVER (ORDER BY annual_salary) AS company_salary_quartile
FROM employee_details
WHERE employment_status = 'Active'
ORDER BY department_name, department_rank, employee_id;

CREATE OR REPLACE VIEW salary_top_earners_by_department AS
SELECT
    department_name,
    department_rank,
    employee_id,
    job_title,
    annual_salary
FROM salary_ranking_within_department
WHERE department_rank <= 3
ORDER BY department_name, department_rank, employee_id;

CREATE OR REPLACE VIEW salary_department_vs_company AS
WITH company AS (
    SELECT MEDIAN(annual_salary) AS company_median_salary
    FROM employees
    WHERE employment_status = 'Active'
),
departments AS (
    SELECT
        department_name,
        COUNT(*) AS active_employees,
        MEDIAN(annual_salary) AS department_median_salary,
        ROUND(AVG(job_level), 2) AS average_job_level
    FROM employee_details
    WHERE employment_status = 'Active'
    GROUP BY department_name
)
SELECT
    d.department_name,
    d.active_employees,
    d.average_job_level,
    d.department_median_salary,
    c.company_median_salary,
    d.department_median_salary - c.company_median_salary AS difference_from_company_median,
    ROUND(100.0 * (d.department_median_salary - c.company_median_salary) / c.company_median_salary, 1)
        AS difference_pct
FROM departments AS d
CROSS JOIN company AS c
ORDER BY difference_pct DESC;

CREATE OR REPLACE VIEW salary_by_department_and_job_level AS
SELECT
    department_name,
    job_level,
    COUNT(*) AS active_employees,
    MEDIAN(annual_salary) AS median_salary,
    CASE WHEN COUNT(*) < 5 THEN 'Too few employees to compare' ELSE 'Comparable' END AS sample_size_note
FROM employee_details
WHERE employment_status = 'Active'
GROUP BY department_name, job_level
ORDER BY job_level, median_salary DESC;

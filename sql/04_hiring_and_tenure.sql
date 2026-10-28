CREATE OR REPLACE VIEW hiring_by_month AS
SELECT
    m.month_start,
    COUNT(e.employee_id) AS hires
FROM reporting_months AS m
LEFT JOIN employees AS e
    ON e.hire_date BETWEEN m.month_start AND m.month_end
GROUP BY m.month_start
ORDER BY m.month_start;

CREATE OR REPLACE VIEW hiring_by_year AS
WITH yearly AS (
    SELECT
        YEAR(hire_date) AS hire_year,
        COUNT(*) AS hires
    FROM employees
    GROUP BY YEAR(hire_date)
)
SELECT
    hire_year,
    hires,
    hires - LAG(hires) OVER (ORDER BY hire_year) AS change_from_prior_year,
    ROUND(100.0 * (hires - LAG(hires) OVER (ORDER BY hire_year)) / LAG(hires) OVER (ORDER BY hire_year), 1)
        AS change_from_prior_year_pct
FROM yearly
ORDER BY hire_year;

CREATE OR REPLACE VIEW hiring_seasonality AS
SELECT
    MONTH(hire_date) AS hire_month,
    MONTHNAME(hire_date) AS hire_month_name,
    COUNT(*) AS hires,
    ROUND(COUNT(*) / (SELECT COUNT(DISTINCT YEAR(hire_date)) FROM employees), 1) AS average_hires_per_year
FROM employees
GROUP BY MONTH(hire_date), MONTHNAME(hire_date)
ORDER BY hire_month;

CREATE OR REPLACE VIEW hiring_by_department AS
SELECT
    department_name,
    COUNT(*) AS total_hires,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS share_of_hires_pct,
    COUNT(*) FILTER (WHERE YEAR(hire_date) = YEAR(as_of_date())) AS hires_in_reporting_year,
    MIN(hire_date) AS first_hire_date,
    MAX(hire_date) AS latest_hire_date
FROM employee_details
GROUP BY department_name
ORDER BY total_hires DESC;

CREATE OR REPLACE VIEW hiring_by_department_and_year AS
SELECT
    YEAR(hire_date) AS hire_year,
    department_name,
    COUNT(*) AS hires
FROM employee_details
GROUP BY YEAR(hire_date), department_name
ORDER BY hire_year, department_name;

CREATE OR REPLACE VIEW employee_tenure AS
SELECT
    employee_id,
    department_name,
    job_title,
    employment_status,
    hire_date,
    COALESCE(termination_date, as_of_date()) AS tenure_end_date,
    DATEDIFF('day', hire_date, COALESCE(termination_date, as_of_date())) AS tenure_days,
    ROUND(DATEDIFF('day', hire_date, COALESCE(termination_date, as_of_date())) / 365.25, 2) AS tenure_years,
    CASE
        WHEN DATEDIFF('day', hire_date, COALESCE(termination_date, as_of_date())) < 365 THEN '1. Under 1 year'
        WHEN DATEDIFF('day', hire_date, COALESCE(termination_date, as_of_date())) < 730 THEN '2. 1 to 2 years'
        WHEN DATEDIFF('day', hire_date, COALESCE(termination_date, as_of_date())) < 1095 THEN '3. 2 to 3 years'
        WHEN DATEDIFF('day', hire_date, COALESCE(termination_date, as_of_date())) < 1826 THEN '4. 3 to 5 years'
        ELSE '5. 5 years or more'
    END AS tenure_band
FROM employee_details;

CREATE OR REPLACE VIEW tenure_summary_by_status AS
SELECT
    employment_status,
    COUNT(*) AS employees,
    ROUND(AVG(tenure_years), 2) AS average_tenure_years,
    ROUND(MEDIAN(tenure_years), 2) AS median_tenure_years,
    MIN(tenure_days) AS minimum_tenure_days,
    MAX(tenure_days) AS maximum_tenure_days
FROM employee_tenure
GROUP BY employment_status
ORDER BY employment_status;

CREATE OR REPLACE VIEW tenure_distribution_active AS
SELECT
    tenure_band,
    COUNT(*) AS active_employees,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS share_pct
FROM employee_tenure
WHERE employment_status = 'Active'
GROUP BY tenure_band
ORDER BY tenure_band;

CREATE OR REPLACE VIEW tenure_bands_by_department AS
SELECT
    department_name,
    COUNT(*) FILTER (WHERE tenure_band = '1. Under 1 year') AS under_1_year,
    COUNT(*) FILTER (WHERE tenure_band = '2. 1 to 2 years') AS from_1_to_2_years,
    COUNT(*) FILTER (WHERE tenure_band = '3. 2 to 3 years') AS from_2_to_3_years,
    COUNT(*) FILTER (WHERE tenure_band = '4. 3 to 5 years') AS from_3_to_5_years,
    COUNT(*) FILTER (WHERE tenure_band = '5. 5 years or more') AS five_years_or_more,
    COUNT(*) AS active_employees,
    ROUND(MEDIAN(tenure_years), 2) AS median_tenure_years
FROM employee_tenure
WHERE employment_status = 'Active'
GROUP BY department_name
ORDER BY median_tenure_years DESC;

CREATE OR REPLACE VIEW longest_serving_active_employees AS
SELECT
    service_rank,
    employee_id,
    department_name,
    job_title,
    hire_date,
    tenure_years
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER (ORDER BY hire_date, employee_id) AS service_rank
    FROM employee_tenure
    WHERE employment_status = 'Active'
) AS ranked
WHERE service_rank <= 10
ORDER BY service_rank;

CREATE OR REPLACE VIEW hiring_cohort_comparison AS
SELECT
    YEAR(hire_date) AS hire_cohort,
    COUNT(*) AS hires,
    COUNT(*) FILTER (WHERE employment_status = 'Active') AS still_active,
    ROUND(100.0 * COUNT(*) FILTER (WHERE employment_status = 'Active') / COUNT(*), 1) AS still_active_pct,
    COUNT(*) FILTER (WHERE hire_date + INTERVAL 365 DAY <= as_of_date()) AS hires_observable_for_one_year,
    COUNT(*) FILTER (
        WHERE hire_date + INTERVAL 365 DAY <= as_of_date()
          AND (termination_date IS NULL OR termination_date > hire_date + INTERVAL 365 DAY)
    ) AS retained_one_year,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE hire_date + INTERVAL 365 DAY <= as_of_date()
              AND (termination_date IS NULL OR termination_date > hire_date + INTERVAL 365 DAY)
        ) / NULLIF(COUNT(*) FILTER (WHERE hire_date + INTERVAL 365 DAY <= as_of_date()), 0),
        1
    ) AS one_year_retention_pct,
    ROUND(MEDIAN(DATEDIFF('day', hire_date, termination_date)) / 365.25, 2) AS median_tenure_of_leavers_years
FROM employees
GROUP BY YEAR(hire_date)
ORDER BY hire_cohort;

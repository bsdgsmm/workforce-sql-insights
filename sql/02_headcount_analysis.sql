CREATE OR REPLACE VIEW headcount_current_total AS
SELECT
    as_of_date() AS reporting_date,
    COUNT(*) AS active_headcount
FROM employees
WHERE hire_date <= as_of_date()
  AND (termination_date IS NULL OR termination_date > as_of_date());

CREATE OR REPLACE VIEW headcount_by_department AS
SELECT
    department_name,
    COUNT(*) AS active_headcount,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS share_of_headcount_pct
FROM employee_details
WHERE employment_status = 'Active'
GROUP BY department_name
ORDER BY active_headcount DESC;

CREATE OR REPLACE VIEW headcount_top_job_titles AS
SELECT
    job_title,
    department_name,
    job_level,
    COUNT(*) AS active_headcount
FROM employee_details
WHERE employment_status = 'Active'
GROUP BY job_title, department_name, job_level
ORDER BY active_headcount DESC, job_title
LIMIT 10;

CREATE OR REPLACE VIEW headcount_by_employment_type AS
SELECT
    employment_type,
    COUNT(*) AS active_headcount,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS share_of_headcount_pct
FROM employees
WHERE employment_status = 'Active'
GROUP BY employment_type
ORDER BY active_headcount DESC;

CREATE OR REPLACE VIEW headcount_employment_type_by_department AS
SELECT
    department_name,
    COUNT(*) FILTER (WHERE employment_type = 'Full-time') AS full_time,
    COUNT(*) FILTER (WHERE employment_type = 'Part-time') AS part_time,
    COUNT(*) FILTER (WHERE employment_type = 'Contract') AS contract,
    COUNT(*) AS active_headcount,
    ROUND(100.0 * COUNT(*) FILTER (WHERE employment_type <> 'Full-time') / COUNT(*), 1) AS non_full_time_pct
FROM employee_details
WHERE employment_status = 'Active'
GROUP BY department_name
ORDER BY active_headcount DESC;

CREATE OR REPLACE VIEW headcount_by_location AS
SELECT
    region,
    location_name,
    COUNT(*) AS active_headcount
FROM employee_details
WHERE employment_status = 'Active'
GROUP BY region, location_name
ORDER BY active_headcount DESC;

CREATE OR REPLACE VIEW headcount_month_end AS
SELECT
    m.month_start,
    m.month_end,
    COUNT(*) FILTER (
        WHERE e.hire_date <= m.month_end
          AND (e.termination_date IS NULL OR e.termination_date > m.month_end)
    ) AS month_end_headcount,
    COUNT(*) FILTER (WHERE e.hire_date BETWEEN m.month_start AND m.month_end) AS hires,
    COUNT(*) FILTER (WHERE e.termination_date BETWEEN m.month_start AND m.month_end) AS terminations
FROM reporting_months AS m
CROSS JOIN employees AS e
GROUP BY m.month_start, m.month_end
ORDER BY m.month_start;

CREATE OR REPLACE VIEW headcount_year_end_by_department AS
WITH year_ends AS (
    SELECT DISTINCT
        YEAR(month_end) AS calendar_year,
        MAKE_DATE(YEAR(month_end), 12, 31) AS year_end_date
    FROM reporting_months
)
SELECT
    y.calendar_year,
    ed.department_name,
    COUNT(*) AS year_end_headcount
FROM year_ends AS y
INNER JOIN employee_details AS ed
    ON ed.hire_date <= y.year_end_date
   AND (ed.termination_date IS NULL OR ed.termination_date > y.year_end_date)
GROUP BY y.calendar_year, ed.department_name
ORDER BY y.calendar_year, ed.department_name;

CREATE OR REPLACE VIEW headcount_year_end_summary AS
SELECT
    calendar_year,
    SUM(year_end_headcount) AS year_end_headcount,
    SUM(year_end_headcount) - LAG(SUM(year_end_headcount)) OVER (ORDER BY calendar_year) AS change_from_prior_year
FROM headcount_year_end_by_department
GROUP BY calendar_year
ORDER BY calendar_year;

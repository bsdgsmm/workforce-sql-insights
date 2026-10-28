CREATE OR REPLACE VIEW advanced_quarterly_hiring_comparison AS
WITH quarterly AS (
    SELECT
        DATE_TRUNC('quarter', hire_date) AS quarter_start,
        COUNT(*) AS hires
    FROM employees
    GROUP BY DATE_TRUNC('quarter', hire_date)
)
SELECT
    CAST(quarter_start AS DATE) AS quarter_start,
    YEAR(quarter_start) || '-Q' || QUARTER(quarter_start) AS quarter_label,
    hires,
    LAG(hires) OVER (ORDER BY quarter_start) AS prior_quarter_hires,
    hires - LAG(hires) OVER (ORDER BY quarter_start) AS quarter_over_quarter_change,
    LAG(hires, 4) OVER (ORDER BY quarter_start) AS same_quarter_prior_year_hires,
    ROUND(100.0 * (hires - LAG(hires, 4) OVER (ORDER BY quarter_start)) / LAG(hires, 4) OVER (ORDER BY quarter_start), 1)
        AS year_over_year_change_pct
FROM quarterly
ORDER BY quarter_start;

CREATE OR REPLACE VIEW advanced_month_over_month_headcount AS
WITH month_end AS (
    SELECT
        m.month_start,
        COUNT(e.employee_id) AS month_end_headcount
    FROM reporting_months AS m
    LEFT JOIN employees AS e
        ON e.hire_date <= m.month_end
       AND (e.termination_date IS NULL OR e.termination_date > m.month_end)
    GROUP BY m.month_start
)
SELECT
    month_start,
    month_end_headcount,
    month_end_headcount - LAG(month_end_headcount) OVER (ORDER BY month_start) AS month_over_month_change,
    month_end_headcount - LAG(month_end_headcount, 12) OVER (ORDER BY month_start) AS twelve_month_change,
    LEAD(month_end_headcount) OVER (ORDER BY month_start) AS next_month_headcount
FROM month_end
ORDER BY month_start;

CREATE OR REPLACE VIEW advanced_running_hires_by_department AS
SELECT
    department_name,
    YEAR(hire_date) AS hire_year,
    COUNT(*) AS hires,
    SUM(COUNT(*)) OVER (PARTITION BY department_name ORDER BY YEAR(hire_date)) AS running_total_hires,
    ROUND(
        100.0 * SUM(COUNT(*)) OVER (PARTITION BY department_name ORDER BY YEAR(hire_date))
        / SUM(COUNT(*)) OVER (PARTITION BY department_name),
        1
    ) AS running_share_of_department_hires_pct
FROM employee_details
GROUP BY department_name, YEAR(hire_date)
ORDER BY department_name, hire_year;

CREATE OR REPLACE VIEW advanced_top_hiring_department_by_year AS
WITH ranked AS (
    SELECT
        YEAR(hire_date) AS hire_year,
        department_name,
        COUNT(*) AS hires,
        ROW_NUMBER() OVER (PARTITION BY YEAR(hire_date) ORDER BY COUNT(*) DESC, department_name) AS row_number_rank,
        RANK() OVER (PARTITION BY YEAR(hire_date) ORDER BY COUNT(*) DESC) AS hires_rank,
        DENSE_RANK() OVER (PARTITION BY YEAR(hire_date) ORDER BY COUNT(*) DESC) AS hires_dense_rank
    FROM employee_details
    GROUP BY YEAR(hire_date), department_name
)
SELECT hire_year, department_name, hires, hires_rank, hires_dense_rank
FROM ranked
WHERE row_number_rank <= 2
ORDER BY hire_year, row_number_rank;

CREATE OR REPLACE VIEW advanced_days_between_department_hires AS
WITH sequenced AS (
    SELECT
        department_name,
        hire_date,
        LEAD(hire_date) OVER (PARTITION BY department_name ORDER BY hire_date, employee_id) AS next_hire_date
    FROM employee_details
)
SELECT
    department_name,
    COUNT(next_hire_date) AS hire_intervals,
    ROUND(AVG(DATEDIFF('day', hire_date, next_hire_date)), 1) AS average_days_between_hires,
    MAX(DATEDIFF('day', hire_date, next_hire_date)) AS longest_gap_days
FROM sequenced
GROUP BY department_name
ORDER BY average_days_between_hires;

CREATE OR REPLACE VIEW advanced_above_department_average_salary AS
SELECT
    department_name,
    COUNT(*) AS active_employees,
    COUNT(*) FILTER (
        WHERE annual_salary > (
            SELECT AVG(peer.annual_salary)
            FROM employee_details AS peer
            WHERE peer.employment_status = 'Active'
              AND peer.department_name = outer_employee.department_name
        )
    ) AS above_department_average
FROM employee_details AS outer_employee
WHERE employment_status = 'Active'
GROUP BY department_name
ORDER BY department_name;

CREATE OR REPLACE VIEW advanced_salary_vs_job_peers AS
SELECT
    employee_id,
    job_title,
    annual_salary,
    ROUND(AVG(annual_salary) OVER (PARTITION BY job_id), 0) AS job_average_salary,
    annual_salary - ROUND(AVG(annual_salary) OVER (PARTITION BY job_id), 0) AS difference_from_job_average,
    COUNT(*) OVER (PARTITION BY job_id) AS job_peer_count
FROM employee_details
WHERE employment_status = 'Active'
ORDER BY job_title, annual_salary DESC, employee_id;

CREATE OR REPLACE VIEW advanced_jobs_without_active_employees AS
SELECT
    j.job_id,
    j.job_title,
    d.department_name
FROM jobs AS j
INNER JOIN departments AS d ON j.department_id = d.department_id
WHERE NOT EXISTS (
    SELECT 1
    FROM employees AS e
    WHERE e.job_id = j.job_id
      AND e.employment_status = 'Active'
)
ORDER BY j.job_id;

CREATE OR REPLACE VIEW advanced_departments_above_company_separation_share AS
SELECT
    department_name,
    COUNT(*) AS employee_records,
    COUNT(termination_date) AS separations,
    ROUND(100.0 * COUNT(termination_date) / COUNT(*), 1) AS separated_share_pct
FROM employee_details
GROUP BY department_name
HAVING COUNT(termination_date) * 1.0 / COUNT(*) > (
    SELECT COUNT(termination_date) * 1.0 / COUNT(*) FROM employees
)
ORDER BY separated_share_pct DESC;

CREATE OR REPLACE VIEW advanced_region_employment_type_matrix AS
SELECT
    region,
    SUM(CASE WHEN employment_type = 'Full-time' THEN 1 ELSE 0 END) AS full_time,
    SUM(CASE WHEN employment_type = 'Part-time' THEN 1 ELSE 0 END) AS part_time,
    SUM(CASE WHEN employment_type = 'Contract' THEN 1 ELSE 0 END) AS contract,
    ROUND(AVG(CASE WHEN employment_type = 'Full-time' THEN annual_salary END), 0) AS full_time_average_salary,
    COUNT(*) AS active_headcount
FROM employee_details
WHERE employment_status = 'Active'
GROUP BY region
ORDER BY active_headcount DESC;

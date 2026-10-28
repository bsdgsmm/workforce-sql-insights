CREATE OR REPLACE VIEW data_quality_column_completeness AS
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(employee_id) AS missing_employee_id,
    COUNT(*) - COUNT(job_id) AS missing_job_id,
    COUNT(*) - COUNT(location_id) AS missing_location_id,
    COUNT(*) - COUNT(employment_type) AS missing_employment_type,
    COUNT(*) - COUNT(hire_date) AS missing_hire_date,
    COUNT(*) - COUNT(employment_status) AS missing_employment_status,
    COUNT(*) - COUNT(annual_salary) AS missing_annual_salary,
    COUNT(*) FILTER (WHERE employment_status = 'Terminated' AND termination_date IS NULL)
        AS terminated_missing_termination_date,
    COUNT(*) FILTER (WHERE employment_status = 'Terminated' AND termination_type IS NULL)
        AS terminated_missing_termination_type
FROM employees;

CREATE OR REPLACE VIEW data_quality_potential_duplicate_records AS
SELECT
    job_id,
    location_id,
    employment_type,
    hire_date,
    annual_salary,
    COUNT(*) AS matching_records,
    LIST(employee_id ORDER BY employee_id) AS employee_ids
FROM employees
GROUP BY job_id, location_id, employment_type, hire_date, annual_salary
HAVING COUNT(*) > 1
ORDER BY hire_date;

CREATE OR REPLACE VIEW data_quality_checks AS
WITH checks AS (
    SELECT 'Uniqueness' AS check_category, 'Duplicate employee_id values' AS check_name,
        (SELECT COUNT(*) - COUNT(DISTINCT employee_id) FROM employees) AS failing_rows
    UNION ALL
    SELECT 'Uniqueness', 'Duplicate department names',
        (SELECT COUNT(*) - COUNT(DISTINCT department_name) FROM departments)
    UNION ALL
    SELECT 'Uniqueness', 'Duplicate job titles',
        (SELECT COUNT(*) - COUNT(DISTINCT job_title) FROM jobs)
    UNION ALL
    SELECT 'Uniqueness', 'Employees sharing every descriptive attribute',
        (SELECT COALESCE(SUM(matching_records), 0) FROM data_quality_potential_duplicate_records)
    UNION ALL
    SELECT 'Completeness', 'Missing required employee fields',
        (SELECT COUNT(*) FROM employees
         WHERE job_id IS NULL OR location_id IS NULL OR employment_type IS NULL
            OR hire_date IS NULL OR employment_status IS NULL OR annual_salary IS NULL)
    UNION ALL
    SELECT 'Referential integrity', 'Employees with unknown job_id',
        (SELECT COUNT(*) FROM employees AS e WHERE NOT EXISTS (SELECT 1 FROM jobs AS j WHERE j.job_id = e.job_id))
    UNION ALL
    SELECT 'Referential integrity', 'Employees with unknown location_id',
        (SELECT COUNT(*) FROM employees AS e
         WHERE NOT EXISTS (SELECT 1 FROM locations AS l WHERE l.location_id = e.location_id))
    UNION ALL
    SELECT 'Referential integrity', 'Jobs with unknown department_id',
        (SELECT COUNT(*) FROM jobs AS j
         WHERE NOT EXISTS (SELECT 1 FROM departments AS d WHERE d.department_id = j.department_id))
    UNION ALL
    SELECT 'Date validity', 'Hire date after reporting date',
        (SELECT COUNT(*) FROM employees WHERE hire_date > as_of_date())
    UNION ALL
    SELECT 'Date validity', 'Termination date on or before hire date',
        (SELECT COUNT(*) FROM employees WHERE termination_date <= hire_date)
    UNION ALL
    SELECT 'Date validity', 'Termination date after reporting date',
        (SELECT COUNT(*) FROM employees WHERE termination_date > as_of_date())
    UNION ALL
    SELECT 'Status consistency', 'Active employees with termination details',
        (SELECT COUNT(*) FROM employees
         WHERE employment_status = 'Active' AND (termination_date IS NOT NULL OR termination_type IS NOT NULL))
    UNION ALL
    SELECT 'Status consistency', 'Terminated employees missing termination details',
        (SELECT COUNT(*) FROM employees
         WHERE employment_status = 'Terminated' AND (termination_date IS NULL OR termination_type IS NULL))
    UNION ALL
    SELECT 'Value validity', 'Salaries outside job salary band',
        (SELECT COUNT(*) FROM employee_details WHERE annual_salary NOT BETWEEN salary_band_min AND salary_band_max)
    UNION ALL
    SELECT 'Value validity', 'Unexpected employment type values',
        (SELECT COUNT(*) FROM employees WHERE employment_type NOT IN ('Full-time', 'Part-time', 'Contract'))
)
SELECT
    check_category,
    check_name,
    failing_rows,
    CASE WHEN failing_rows = 0 THEN 'Pass' ELSE 'Fail' END AS check_status
FROM checks
ORDER BY check_category, check_name;

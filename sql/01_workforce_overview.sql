CREATE OR REPLACE VIEW overview_workforce_summary AS
SELECT
    COUNT(*) AS total_employee_records,
    COUNT(*) FILTER (WHERE employment_status = 'Active') AS active_employees,
    COUNT(*) FILTER (WHERE employment_status = 'Terminated') AS former_employees,
    COUNT(termination_date) AS records_with_termination_date,
    COUNT(*) - COUNT(termination_date) AS records_without_termination_date,
    MIN(hire_date) AS earliest_hire_date,
    MAX(hire_date) AS latest_hire_date,
    MAX(termination_date) AS latest_termination_date
FROM employees;

CREATE OR REPLACE VIEW overview_active_engineering_employees AS
SELECT
    employee_id,
    job_title,
    location_name,
    employment_type,
    hire_date,
    annual_salary
FROM employee_details
WHERE employment_status = 'Active'
  AND department_name = 'Engineering'
ORDER BY annual_salary DESC, employee_id;

CREATE OR REPLACE VIEW overview_department_salary_statistics AS
SELECT
    department_name,
    COUNT(*) AS active_employees,
    SUM(annual_salary) AS total_annual_payroll,
    ROUND(AVG(annual_salary), 0) AS average_salary,
    MIN(annual_salary) AS minimum_salary,
    MAX(annual_salary) AS maximum_salary
FROM employee_details
WHERE employment_status = 'Active'
GROUP BY department_name
ORDER BY total_annual_payroll DESC;

CREATE OR REPLACE VIEW overview_departments_with_over_50_active AS
SELECT
    department_name,
    COUNT(*) AS active_employees
FROM employee_details
WHERE employment_status = 'Active'
GROUP BY department_name
HAVING COUNT(*) > 50
ORDER BY active_employees DESC;

CREATE OR REPLACE VIEW overview_status_by_department AS
SELECT
    department_name,
    employment_status,
    COUNT(*) AS employees
FROM employee_details
GROUP BY department_name, employment_status
ORDER BY department_name, employment_status;

CREATE OR REPLACE VIEW overview_employee_status_labels AS
SELECT
    employee_id,
    department_name,
    employment_status,
    COALESCE(CAST(termination_date AS VARCHAR), 'Still employed') AS termination_date_label,
    COALESCE(termination_type, 'Not applicable') AS termination_type_label,
    CASE
        WHEN employment_status = 'Active' AND hire_date > as_of_date() - INTERVAL 90 DAY THEN 'New hire'
        WHEN employment_status = 'Active' THEN 'Established employee'
        WHEN termination_type = 'Voluntary' THEN 'Voluntary leaver'
        ELSE 'Involuntary leaver'
    END AS employee_segment
FROM employee_details
ORDER BY employee_id;

CREATE OR REPLACE VIEW overview_employee_segment_counts AS
SELECT
    employee_segment,
    COUNT(*) AS employees
FROM overview_employee_status_labels
GROUP BY employee_segment
ORDER BY employees DESC;

CREATE OR REPLACE VIEW overview_termination_type_breakdown AS
SELECT
    COALESCE(termination_type, 'Still employed') AS termination_type,
    COUNT(*) AS employees,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS share_of_all_records_pct
FROM employees
GROUP BY COALESCE(termination_type, 'Still employed')
ORDER BY employees DESC;

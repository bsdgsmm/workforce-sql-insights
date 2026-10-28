CREATE OR REPLACE MACRO as_of_date() AS DATE '2025-12-31';

CREATE TABLE departments (
    department_id INTEGER PRIMARY KEY,
    department_name VARCHAR NOT NULL UNIQUE
);

CREATE TABLE locations (
    location_id INTEGER PRIMARY KEY,
    location_name VARCHAR NOT NULL,
    country VARCHAR NOT NULL,
    region VARCHAR NOT NULL
);

CREATE TABLE jobs (
    job_id INTEGER PRIMARY KEY,
    job_title VARCHAR NOT NULL UNIQUE,
    department_id INTEGER NOT NULL REFERENCES departments (department_id),
    job_level INTEGER NOT NULL CHECK (job_level BETWEEN 1 AND 4),
    salary_band_min INTEGER NOT NULL,
    salary_band_max INTEGER NOT NULL,
    CHECK (salary_band_min < salary_band_max)
);

CREATE TABLE employees (
    employee_id INTEGER PRIMARY KEY,
    job_id INTEGER NOT NULL REFERENCES jobs (job_id),
    location_id INTEGER NOT NULL REFERENCES locations (location_id),
    employment_type VARCHAR NOT NULL CHECK (employment_type IN ('Full-time', 'Part-time', 'Contract')),
    hire_date DATE NOT NULL,
    termination_date DATE,
    employment_status VARCHAR NOT NULL CHECK (employment_status IN ('Active', 'Terminated')),
    termination_type VARCHAR CHECK (termination_type IN ('Voluntary', 'Involuntary')),
    annual_salary INTEGER NOT NULL CHECK (annual_salary > 0)
);

INSERT INTO departments
SELECT * FROM read_csv('data/sample/departments.csv', header = true, auto_detect = false,
    columns = {'department_id': 'INTEGER', 'department_name': 'VARCHAR'});

INSERT INTO locations
SELECT * FROM read_csv('data/sample/locations.csv', header = true, auto_detect = false,
    columns = {'location_id': 'INTEGER', 'location_name': 'VARCHAR', 'country': 'VARCHAR', 'region': 'VARCHAR'});

INSERT INTO jobs
SELECT * FROM read_csv('data/sample/jobs.csv', header = true, auto_detect = false,
    columns = {
        'job_id': 'INTEGER', 'job_title': 'VARCHAR', 'department_id': 'INTEGER',
        'job_level': 'INTEGER', 'salary_band_min': 'INTEGER', 'salary_band_max': 'INTEGER'
    });

INSERT INTO employees
SELECT * FROM read_csv('data/sample/employees.csv', header = true, auto_detect = false,
    columns = {
        'employee_id': 'INTEGER', 'job_id': 'INTEGER', 'location_id': 'INTEGER',
        'employment_type': 'VARCHAR', 'hire_date': 'DATE', 'termination_date': 'DATE',
        'employment_status': 'VARCHAR', 'termination_type': 'VARCHAR', 'annual_salary': 'INTEGER'
    });

CREATE OR REPLACE VIEW employee_details AS
SELECT
    e.employee_id,
    e.job_id,
    j.job_title,
    j.job_level,
    d.department_id,
    d.department_name,
    l.location_name,
    l.country,
    l.region,
    e.employment_type,
    e.hire_date,
    e.termination_date,
    e.employment_status,
    e.termination_type,
    e.annual_salary,
    j.salary_band_min,
    j.salary_band_max
FROM employees AS e
INNER JOIN jobs AS j ON e.job_id = j.job_id
INNER JOIN departments AS d ON j.department_id = d.department_id
INNER JOIN locations AS l ON e.location_id = l.location_id;

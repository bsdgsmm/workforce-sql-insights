import csv
import hashlib

from generate_sample_data import DEFAULT_OUTPUT_DIR, generate


def file_digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def test_generator_is_deterministic(tmp_path):
    generate(tmp_path)
    for name in ["departments.csv", "jobs.csv", "locations.csv", "employees.csv"]:
        assert file_digest(tmp_path / name) == file_digest(DEFAULT_OUTPUT_DIR / name)


def test_row_counts_match_csv(scalar):
    with (DEFAULT_OUTPUT_DIR / "employees.csv").open(encoding="utf-8") as handle:
        csv_rows = sum(1 for _ in csv.DictReader(handle))
    assert scalar("SELECT COUNT(*) FROM employees") == csv_rows
    assert scalar("SELECT COUNT(*) FROM employee_details") == csv_rows


def test_employee_ids_are_unique(scalar):
    assert scalar("SELECT COUNT(*) - COUNT(DISTINCT employee_id) FROM employees") == 0


def test_status_matches_termination_fields(scalar):
    inconsistent = scalar(
        """
        SELECT COUNT(*)
        FROM employees
        WHERE (employment_status = 'Active' AND (termination_date IS NOT NULL OR termination_type IS NOT NULL))
           OR (employment_status = 'Terminated' AND (termination_date IS NULL OR termination_type IS NULL))
        """
    )
    assert inconsistent == 0


def test_dates_are_valid(scalar):
    invalid = scalar(
        """
        SELECT COUNT(*)
        FROM employees
        WHERE hire_date > as_of_date()
           OR termination_date <= hire_date
           OR termination_date > as_of_date()
        """
    )
    assert invalid == 0


def test_salaries_fall_within_job_bands(scalar):
    assert scalar(
        "SELECT COUNT(*) FROM employee_details WHERE annual_salary NOT BETWEEN salary_band_min AND salary_band_max"
    ) == 0


def test_dataset_contains_active_and_former_employees(scalar):
    assert scalar("SELECT COUNT(DISTINCT employment_status) FROM employees") == 2
    assert scalar("SELECT MIN(hire_date) FROM employees").year == 2016

import statistics


def test_department_median_matches_python(connection):
    rows = connection.execute(
        "SELECT department_name, annual_salary FROM employee_details WHERE employment_status = 'Active'"
    ).fetchall()
    salaries = {}
    for department, salary in rows:
        salaries.setdefault(department, []).append(salary)
    for department, median_salary, average_salary in connection.execute(
        "SELECT department_name, median_salary, average_salary FROM salary_by_department"
    ).fetchall():
        assert median_salary == statistics.median(salaries[department])
        assert average_salary == round(statistics.mean(salaries[department]))


def test_salary_bands_cover_all_active_employees(scalar):
    active = scalar("SELECT COUNT(*) FROM employees WHERE employment_status = 'Active'")
    assert scalar("SELECT SUM(active_employees) FROM salary_band_distribution") == active
    assert scalar("SELECT MAX(cumulative_employees) FROM salary_band_distribution") == active


def test_job_title_ranges_stay_within_bands(scalar):
    assert scalar(
        """
        SELECT COUNT(*)
        FROM salary_range_by_job_title
        WHERE minimum_salary < salary_band_min OR maximum_salary > salary_band_max
        """
    ) == 0


def test_rank_functions_are_consistent(scalar):
    assert scalar("SELECT COUNT(*) FROM salary_ranking_within_department WHERE department_rank = 1") >= 8
    assert scalar(
        "SELECT COUNT(*) FROM salary_ranking_within_department WHERE department_dense_rank > department_rank"
    ) == 0
    assert scalar(
        "SELECT COUNT(DISTINCT company_salary_quartile) FROM salary_ranking_within_department"
    ) == 4


def test_top_earners_are_highest_paid(scalar):
    assert scalar(
        """
        SELECT COUNT(*)
        FROM salary_top_earners_by_department AS t
        WHERE t.department_rank = 1
          AND t.annual_salary <> (
              SELECT MAX(annual_salary)
              FROM employee_details AS e
              WHERE e.employment_status = 'Active' AND e.department_name = t.department_name
          )
        """
    ) == 0

from datetime import date


def test_hiring_totals_reconcile(scalar):
    total = scalar("SELECT COUNT(*) FROM employees")
    for view, column in [
        ("hiring_by_month", "hires"),
        ("hiring_by_year", "hires"),
        ("hiring_seasonality", "hires"),
        ("hiring_by_department", "total_hires"),
        ("hiring_by_department_and_year", "hires"),
        ("hiring_cohort_comparison", "hires"),
    ]:
        assert scalar(f"SELECT SUM({column}) FROM {view}") == total


def test_monthly_hiring_series_has_no_gaps(scalar):
    assert scalar("SELECT COUNT(*) FROM hiring_by_month") == 120


def test_year_over_year_change_uses_prior_year(connection):
    rows = connection.execute("SELECT hires, change_from_prior_year FROM hiring_by_year ORDER BY hire_year").fetchall()
    assert rows[0][1] is None
    for previous, current in zip(rows, rows[1:]):
        assert current[1] == current[0] - previous[0]


def test_tenure_uses_termination_or_reporting_date(connection):
    for hire_date, termination_date, tenure_days in connection.execute(
        """
        SELECT e.hire_date, e.termination_date, t.tenure_days
        FROM employees AS e
        INNER JOIN employee_tenure AS t USING (employee_id)
        """
    ).fetchall():
        end_date = termination_date or date(2025, 12, 31)
        assert tenure_days == (end_date - hire_date).days
        assert tenure_days > 0 or termination_date is None


def test_tenure_bands_cover_active_employees(scalar):
    active = scalar("SELECT COUNT(*) FROM employees WHERE employment_status = 'Active'")
    assert scalar("SELECT SUM(active_employees) FROM tenure_distribution_active") == active
    assert scalar(
        """
        SELECT SUM(under_1_year + from_1_to_2_years + from_2_to_3_years + from_3_to_5_years + five_years_or_more)
        FROM tenure_bands_by_department
        """
    ) == active


def test_longest_serving_employees_are_earliest_active_hires(scalar):
    assert scalar("SELECT COUNT(*) FROM longest_serving_active_employees") == 10
    assert scalar("SELECT hire_date FROM longest_serving_active_employees WHERE service_rank = 1") == scalar(
        "SELECT MIN(hire_date) FROM employees WHERE employment_status = 'Active'"
    )


def test_one_year_retention_excludes_unobservable_hires(scalar):
    assert scalar("SELECT hires_observable_for_one_year FROM hiring_cohort_comparison WHERE hire_cohort = 2025") == 0
    assert scalar("SELECT one_year_retention_pct FROM hiring_cohort_comparison WHERE hire_cohort = 2025") is None
    assert scalar(
        "SELECT COUNT(*) FROM hiring_cohort_comparison WHERE retained_one_year > hires_observable_for_one_year"
    ) == 0

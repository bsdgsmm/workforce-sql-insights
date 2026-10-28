def test_summary_counts_reconcile(connection, scalar):
    total, active, former, with_date, without_date = connection.execute(
        """
        SELECT total_employee_records, active_employees, former_employees,
               records_with_termination_date, records_without_termination_date
        FROM overview_workforce_summary
        """
    ).fetchone()
    assert total == scalar("SELECT COUNT(*) FROM employees")
    assert active + former == total
    assert with_date == former
    assert without_date == active


def test_department_statistics_cover_all_active_employees(scalar):
    assert scalar("SELECT SUM(active_employees) FROM overview_department_salary_statistics") == scalar(
        "SELECT COUNT(*) FROM employees WHERE employment_status = 'Active'"
    )
    assert scalar("SELECT SUM(total_annual_payroll) FROM overview_department_salary_statistics") == scalar(
        "SELECT SUM(annual_salary) FROM employees WHERE employment_status = 'Active'"
    )


def test_having_filter_applies_threshold(scalar):
    assert scalar("SELECT MIN(active_employees) FROM overview_departments_with_over_50_active") > 50


def test_segments_cover_every_employee(scalar):
    assert scalar("SELECT SUM(employees) FROM overview_employee_segment_counts") == scalar(
        "SELECT COUNT(*) FROM employees"
    )
    assert scalar("SELECT SUM(share_of_all_records_pct) FROM overview_termination_type_breakdown") == 100.0

def test_quarterly_comparisons_use_correct_offsets(connection):
    rows = connection.execute(
        "SELECT hires, prior_quarter_hires, same_quarter_prior_year_hires FROM advanced_quarterly_hiring_comparison"
    ).fetchall()
    assert len(rows) == 40
    for index, (_, prior_quarter, prior_year) in enumerate(rows):
        assert prior_quarter == (rows[index - 1][0] if index >= 1 else None)
        assert prior_year == (rows[index - 4][0] if index >= 4 else None)


def test_month_over_month_headcount_matches_headcount_view(scalar):
    assert scalar(
        """
        SELECT COUNT(*)
        FROM advanced_month_over_month_headcount AS a
        INNER JOIN headcount_month_end AS h USING (month_start)
        WHERE a.month_end_headcount <> h.month_end_headcount
        """
    ) == 0


def test_running_totals_end_at_department_totals(scalar):
    assert scalar(
        """
        SELECT COUNT(*)
        FROM (
            SELECT department_name, MAX(running_total_hires) AS final_total
            FROM advanced_running_hires_by_department
            GROUP BY department_name
        ) AS r
        INNER JOIN hiring_by_department AS h USING (department_name)
        WHERE r.final_total <> h.total_hires
        """
    ) == 0
    assert scalar(
        "SELECT MIN(running_share_of_department_hires_pct) FROM advanced_running_hires_by_department WHERE hire_year = 2025"
    ) == 100.0


def test_top_hiring_department_ranks(scalar):
    assert scalar("SELECT COUNT(*) FROM advanced_top_hiring_department_by_year") == 20
    assert scalar("SELECT MIN(hires_rank) FROM advanced_top_hiring_department_by_year") == 1


def test_above_average_counts_match_window_calculation(scalar):
    assert scalar("SELECT SUM(above_department_average) FROM advanced_above_department_average_salary") == scalar(
        """
        SELECT COUNT(*)
        FROM (
            SELECT annual_salary, AVG(annual_salary) OVER (PARTITION BY department_name) AS department_average
            FROM employee_details
            WHERE employment_status = 'Active'
        )
        WHERE annual_salary > department_average
        """
    )


def test_hire_intervals_and_matrix_reconcile(scalar):
    assert scalar("SELECT SUM(hire_intervals) FROM advanced_days_between_department_hires") == scalar(
        "SELECT COUNT(*) - 8 FROM employees"
    )
    assert scalar(
        "SELECT SUM(full_time + part_time + contract) FROM advanced_region_employment_type_matrix"
    ) == scalar("SELECT COUNT(*) FROM employees WHERE employment_status = 'Active'")


def test_departments_above_company_separation_share(scalar):
    company_share = scalar(
        "SELECT 100.0 * COUNT(termination_date) / COUNT(*) FROM employees"
    )
    assert scalar(
        "SELECT MIN(separated_share_pct) FROM advanced_departments_above_company_separation_share"
    ) >= round(company_share, 1)

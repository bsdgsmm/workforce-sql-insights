from datetime import date


def test_current_headcount_matches_active_status(scalar):
    assert scalar("SELECT active_headcount FROM headcount_current_total") == scalar(
        "SELECT COUNT(*) FROM employees WHERE employment_status = 'Active'"
    )


def test_breakdowns_sum_to_current_headcount(scalar):
    current = scalar("SELECT active_headcount FROM headcount_current_total")
    for view in [
        "headcount_by_department",
        "headcount_by_employment_type",
        "headcount_by_location",
        "headcount_employment_type_by_department",
    ]:
        assert scalar(f"SELECT SUM(active_headcount) FROM {view}") == current
    assert scalar(
        "SELECT SUM(full_time + part_time + contract) FROM headcount_employment_type_by_department"
    ) == current


def test_month_end_headcount_rolls_forward(connection):
    rows = connection.execute(
        "SELECT month_end_headcount, hires, terminations FROM headcount_month_end ORDER BY month_start"
    ).fetchall()
    previous = 0
    for headcount, hires, terminations in rows:
        assert headcount == previous + hires - terminations
        previous = headcount


def test_month_end_series_is_complete(connection, scalar):
    months = connection.execute("SELECT month_start FROM headcount_month_end ORDER BY month_start").fetchall()
    assert months[0][0] == date(2016, 1, 1)
    assert months[-1][0] == date(2025, 12, 1)
    assert len(months) == 120
    assert scalar(
        "SELECT month_end_headcount FROM headcount_month_end WHERE month_start = DATE '2025-12-01'"
    ) == scalar("SELECT active_headcount FROM headcount_current_total")


def test_year_end_summary_matches_month_end_series(scalar):
    mismatches = scalar(
        """
        SELECT COUNT(*)
        FROM headcount_year_end_summary AS y
        INNER JOIN headcount_month_end AS m
            ON m.month_end = MAKE_DATE(y.calendar_year, 12, 31)
        WHERE y.year_end_headcount <> m.month_end_headcount
        """
    )
    assert mismatches == 0
    assert scalar("SELECT COUNT(*) FROM headcount_year_end_summary") == 10

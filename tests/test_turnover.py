from datetime import date, timedelta

import pytest


def headcount_on(connection, day):
    return connection.execute(
        """
        SELECT COUNT(*)
        FROM employees
        WHERE hire_date <= ? AND (termination_date IS NULL OR termination_date > ?)
        """,
        [day, day],
    ).fetchone()[0]


def test_opening_headcount_equals_prior_closing(connection):
    rows = connection.execute(
        "SELECT opening_headcount, closing_headcount FROM turnover_monthly ORDER BY month_start"
    ).fetchall()
    assert rows[0][0] == 0
    for previous, current in zip(rows, rows[1:]):
        assert current[0] == previous[1]


def test_monthly_headcount_matches_point_in_time_count(connection):
    for month_start, opening, closing in connection.execute(
        "SELECT month_start, opening_headcount, closing_headcount FROM turnover_monthly WHERE MONTH(month_start) IN (1, 7)"
    ).fetchall():
        assert opening == headcount_on(connection, month_start - timedelta(days=1))
        next_month = date(month_start.year + month_start.month // 12, month_start.month % 12 + 1, 1)
        assert closing == headcount_on(connection, next_month - timedelta(days=1))


def test_annual_turnover_formula(connection):
    year = 2024
    separations = connection.execute(
        "SELECT COUNT(*) FROM employees WHERE YEAR(termination_date) = ?", [year]
    ).fetchone()[0]
    month_ends = [
        date(year + month // 12, month % 12 + 1, 1) - timedelta(days=1) for month in range(1, 13)
    ]
    average_headcount = sum(headcount_on(connection, day) for day in month_ends) / 12
    reported_separations, reported_rate = connection.execute(
        "SELECT separations, annual_turnover_pct FROM turnover_annual WHERE calendar_year = ?", [year]
    ).fetchone()
    assert reported_separations == separations
    assert reported_rate == pytest.approx(round(100 * separations / average_headcount, 1))


def test_separations_reconcile_across_views(scalar):
    terminated = scalar("SELECT COUNT(*) FROM employees WHERE employment_status = 'Terminated'")
    assert scalar("SELECT SUM(separations) FROM turnover_monthly") == terminated
    assert scalar("SELECT SUM(separations) FROM turnover_annual") == terminated
    assert scalar("SELECT SUM(separations) FROM turnover_by_department_annual") == terminated
    assert scalar("SELECT SUM(terminations) FROM hires_vs_terminations_by_year") == terminated
    assert scalar("SELECT SUM(separations) FROM separations_by_tenure_at_exit") == terminated
    assert scalar(
        "SELECT SUM(voluntary_separations + involuntary_separations) FROM turnover_annual"
    ) == terminated


def test_department_monthly_headcount_sums_to_company(scalar):
    assert scalar(
        """
        SELECT COUNT(*)
        FROM (
            SELECT month_start, SUM(closing_headcount) AS closing_headcount
            FROM turnover_department_monthly
            GROUP BY month_start
        ) AS d
        INNER JOIN turnover_monthly AS c USING (month_start)
        WHERE d.closing_headcount <> c.closing_headcount
        """
    ) == 0


def test_cumulative_net_change_equals_current_headcount(scalar):
    assert scalar(
        "SELECT cumulative_net_change FROM hires_vs_terminations_by_year ORDER BY calendar_year DESC LIMIT 1"
    ) == scalar("SELECT COUNT(*) FROM employees WHERE employment_status = 'Active'")


def test_recent_window_covers_three_years(scalar):
    assert scalar(
        "SELECT SUM(separations) FROM turnover_by_department_recent"
    ) == scalar("SELECT COUNT(*) FROM employees WHERE termination_date >= DATE '2023-01-01'")
    assert scalar("SELECT SUM(separations) FROM turnover_by_employment_type_recent") == scalar(
        "SELECT COUNT(*) FROM employees WHERE termination_date >= DATE '2023-01-01'"
    )

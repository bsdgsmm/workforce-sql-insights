from run_analysis import SQL_DIR, build_connection, execute_script


def test_all_checks_pass_on_sample_data(connection):
    failing = connection.execute(
        "SELECT check_name, failing_rows FROM data_quality_checks WHERE check_status <> 'Pass'"
    ).fetchall()
    assert failing == []
    assert connection.execute("SELECT COUNT(*) FROM data_quality_checks").fetchone()[0] == 15


def test_completeness_view_reports_no_missing_values(connection):
    row = connection.execute("SELECT * EXCLUDE (total_rows) FROM data_quality_column_completeness").fetchone()
    assert all(value == 0 for value in row)


def test_checks_detect_injected_issues():
    con = build_connection()
    try:
        con.execute(
            """
            INSERT INTO employees VALUES
                (90001, 101, 1, 'Full-time', DATE '2024-05-01', DATE '2024-04-01', 'Terminated', 'Voluntary', 80000),
                (90002, 101, 1, 'Full-time', DATE '2024-05-01', DATE '2025-01-15', 'Active', NULL, 80000),
                (90003, 101, 1, 'Full-time', DATE '2024-05-01', NULL, 'Active', NULL, 250000)
            """
        )
        execute_script(con, SQL_DIR / "07_data_quality.sql")
        results = dict(con.execute("SELECT check_name, failing_rows FROM data_quality_checks").fetchall())
    finally:
        con.close()
    assert results["Termination date on or before hire date"] == 1
    assert results["Active employees with termination details"] == 1
    assert results["Salaries outside job salary band"] == 1
    assert results["Employees sharing every descriptive attribute"] == 2

import pytest

from run_analysis import SQL_DIR, analysis_files, build_connection, execute_script, run_analyses


@pytest.mark.parametrize("path", analysis_files(), ids=lambda path: path.name)
def test_each_analysis_file_runs_independently(path):
    con = build_connection()
    try:
        execute_script(con, path)
        views = con.execute(
            "SELECT view_name FROM duckdb_views() WHERE NOT internal AND schema_name = 'main'"
        ).fetchall()
        for (view,) in views:
            con.sql(f'SELECT * FROM "{view}"').fetchall()
    finally:
        con.close()


def test_runner_exports_every_view(tmp_path):
    con = build_connection()
    try:
        created = run_analyses(con, tmp_path)
    finally:
        con.close()
    assert set(created) == {path.name for path in analysis_files()}
    exported = sorted(path.stem for path in tmp_path.rglob("*.csv"))
    assert exported == sorted(view for views in created.values() for view in views)
    assert all(views for views in created.values())


def test_sql_files_contain_no_comments():
    for path in SQL_DIR.glob("*.sql"):
        text = path.read_text(encoding="utf-8")
        assert "--" not in text and "/*" not in text, path.name

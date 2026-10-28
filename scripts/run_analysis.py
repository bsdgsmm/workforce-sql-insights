import argparse
from pathlib import Path

import duckdb

PROJECT_ROOT = Path(__file__).resolve().parent.parent
SQL_DIR = PROJECT_ROOT / "sql"
LOAD_SCRIPT = "00_load_data.sql"


def analysis_files():
    return sorted(path for path in SQL_DIR.glob("*.sql") if path.name != LOAD_SCRIPT)


def view_names(connection):
    rows = connection.execute(
        "SELECT view_name FROM duckdb_views() WHERE NOT internal AND schema_name = 'main'"
    ).fetchall()
    return {row[0] for row in rows}


def execute_script(connection, path):
    for statement in duckdb.extract_statements(path.read_text(encoding="utf-8")):
        connection.execute(statement)


def build_connection(database=":memory:"):
    connection = duckdb.connect(str(database))
    connection.execute(f"SET file_search_path = '{PROJECT_ROOT.as_posix()}'")
    execute_script(connection, SQL_DIR / LOAD_SCRIPT)
    return connection


def run_analyses(connection, output_dir=None):
    created_views = {}
    for path in analysis_files():
        existing = view_names(connection)
        execute_script(connection, path)
        new_views = sorted(view_names(connection) - existing)
        created_views[path.name] = new_views
        for view in new_views:
            relation = connection.sql(f'SELECT * FROM "{view}"')
            if output_dir is not None:
                target = Path(output_dir) / path.stem
                target.mkdir(parents=True, exist_ok=True)
                relation.write_csv(str(target / f"{view}.csv"))
            else:
                relation.fetchall()
    return created_views


def main():
    parser = argparse.ArgumentParser(
        description="Load the sample dataset into DuckDB and run every analysis script."
    )
    parser.add_argument("--database", default=":memory:", help="DuckDB database file to build.")
    parser.add_argument("--output-dir", type=Path, help="Directory for exported query results.")
    args = parser.parse_args()

    if args.database != ":memory:" and Path(args.database).exists():
        parser.error(f"{args.database} already exists; choose a new database path.")

    connection = build_connection(args.database)
    try:
        run_analyses(connection, args.output_dir)
    finally:
        connection.close()


if __name__ == "__main__":
    main()

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))

from run_analysis import build_connection, run_analyses


@pytest.fixture(scope="session")
def connection():
    con = build_connection()
    run_analyses(con)
    yield con
    con.close()


@pytest.fixture(scope="session")
def scalar(connection):
    def query(sql, params=None):
        return connection.execute(sql, params or []).fetchone()[0]

    return query

"""SQLite setup and seed loading — stdlib sqlite3 + csv only."""

import csv
import sqlite3
from pathlib import Path

# Paths are resolved relative to the code/ directory (this file's parent's parent).
CODE_DIR = Path(__file__).resolve().parent.parent
SCHEMA_PATH = CODE_DIR / "schema.sql"
SEED_DIR = CODE_DIR / "seed_data"


def connect(db_path=":memory:"):
    """Open a SQLite connection with row access by column name."""
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    return conn


def build_db(conn):
    """Create tables from schema.sql (idempotent)."""
    conn.executescript(SCHEMA_PATH.read_text(encoding="utf-8"))
    conn.commit()


def _load_csv(conn, table, csv_path, columns):
    """Bulk-insert a CSV into `table` for the given column order."""
    placeholders = ",".join("?" for _ in columns)
    sql = f"INSERT INTO {table} ({','.join(columns)}) VALUES ({placeholders})"
    with open(csv_path, newline="", encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        rows = [tuple(row[c] for c in columns) for row in reader]
    conn.executemany(sql, rows)
    conn.commit()
    return len(rows)


def load_seed(conn):
    """Load the bundled sample drugs + pharmacies. Returns (n_drugs, n_pharmacies)."""
    n_drugs = _load_csv(
        conn,
        "drugs",
        SEED_DIR / "drugs.csv",
        ["name", "salt", "strength", "form", "mrp_inr", "pack", "is_generic", "schedule", "source"],
    )
    n_ph = _load_csv(
        conn,
        "pharmacies",
        SEED_DIR / "pharmacies.csv",
        ["name", "kind", "city", "area", "lat", "lon"],
    )
    return n_drugs, n_ph

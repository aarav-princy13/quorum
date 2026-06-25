#!/usr/bin/env python3
"""Query the real ingested catalog (data/b2g.db) with brand names.

Examples:
  python3 code/query.py                                  # runs a sample receipt
  python3 code/query.py "Augmentin 625 Duo Tablet" "Pan 40 Tablet"

Each argument is treated as one receipt line item (qty 1). Build the DB first
with:  python3 code/ingest.py
"""

import json
import sqlite3
import sys
from pathlib import Path

CODE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(CODE_DIR))
DB_PATH = CODE_DIR.parent / "data" / "b2g.db"
OUTPUT_DIR = CODE_DIR.parent / "output"

from b2g.pipeline import process_receipt, nearby_pharmacies  # noqa: E402
from b2g.report import build_report                          # noqa: E402

# Real catalog product names (as printed) for the default demo.
SAMPLE = [
    "Augmentin 625 Duo Tablet",
    "Azithral 500 Tablet",
    "Pan 40 Tablet",
    "Glycomet 500 Tablet",
    "Alprax 0.25 Tablet",
]


def main():
    if not DB_PATH.exists():
        sys.exit(f"DB not found: {DB_PATH}\nBuild it first:  python3 code/ingest.py")

    names = sys.argv[1:] or SAMPLE
    line_items = [{"name": n, "qty": 1} for n in names]

    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    result = process_receipt(conn, line_items)
    # stand-in for the app passing the user's GPS location (Chandigarh, Sector 17)
    pharmacies = nearby_pharmacies(conn, lat=30.7411, lon=76.7820)
    report = build_report(result, pharmacies, title="receipt analysis (real catalog)")
    print(report)
    conn.close()

    OUTPUT_DIR.mkdir(exist_ok=True)
    (OUTPUT_DIR / "real_query_result.json").write_text(
        json.dumps({"result": result, "pharmacies": pharmacies}, indent=2, ensure_ascii=False),
        encoding="utf-8")
    (OUTPUT_DIR / "real_query_report.txt").write_text(report, encoding="utf-8")


if __name__ == "__main__":
    main()

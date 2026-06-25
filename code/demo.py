#!/usr/bin/env python3
"""Runnable demo of the brand_to_generic backend (stdlib only).

Simulates what the Flutter app will send AFTER on-device OCR: a list of text
line items from a pharmacy receipt. Runs the pipeline (generic match + savings +
Schedule H/H1/X safety), prints a readable report, and writes artifacts to output/.

Run from the repo root:  python3 code/demo.py
"""

import json
import sys
from pathlib import Path

# Make the b2g package importable when run as a script.
CODE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(CODE_DIR))
OUTPUT_DIR = CODE_DIR.parent / "output"

from b2g.db import connect, build_db, load_seed              # noqa: E402
from b2g.pipeline import process_receipt, nearby_pharmacies  # noqa: E402
from b2g.report import build_report                          # noqa: E402

# A stand-in for an OCR'd Chandigarh pharmacy receipt (names as they'd be printed).
SAMPLE_RECEIPT = [
    {"name": "Crocin 500", "qty": 2},
    {"name": "Augmentin 625 Duo", "qty": 1},   # antibiotic -> prescription warning
    {"name": "Pan 40", "qty": 1},
    {"name": "Alprax 0.5", "qty": 1},          # alprazolam -> H1, overdose-risk warning
    {"name": "Vitamin C Chewable", "qty": 1},  # not in catalog -> shows "not found" path
]


def main():
    conn = connect()             # in-memory DB for the demo
    build_db(conn)
    n_drugs, n_ph = load_seed(conn)

    result = process_receipt(conn, SAMPLE_RECEIPT)
    pharmacies = nearby_pharmacies(conn, lat=30.7411, lon=76.7820)
    report = build_report(result, pharmacies, title="receipt analysis (DEMO / illustrative seed prices)")
    print(report)

    OUTPUT_DIR.mkdir(exist_ok=True)
    (OUTPUT_DIR / "demo_result.json").write_text(
        json.dumps({"result": result, "pharmacies": pharmacies}, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    (OUTPUT_DIR / "demo_report.txt").write_text(report, encoding="utf-8")
    print(f"\n[loaded {n_drugs} drugs, {n_ph} pharmacies]")
    print(f"[wrote {OUTPUT_DIR / 'demo_result.json'} and demo_report.txt]")


if __name__ == "__main__":
    main()

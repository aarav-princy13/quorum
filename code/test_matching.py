#!/usr/bin/env python3
"""Regression tests for brand-name matching (exact / prefix / fuzzy).

The bar is PRECISION over recall: in a health app a wrong match (wrong drug or
wrong strength) is far worse than a miss. So every case below asserts the matched
COMPOSITION, and the safety cases assert we do NOT match the wrong drug.

Run (after building data/b2g.db):  python3 code/test_matching.py
Exits non-zero if any case regresses.
"""

import sqlite3
import sys
from pathlib import Path

CODE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(CODE_DIR))
DB_PATH = CODE_DIR.parent / "data" / "b2g.db"

from b2g.matcher import find_alternatives  # noqa: E402

# (query, expected_salt, expected_strength)  — expected_strength None = don't care
SHOULD_MATCH = [
    ("Glycomet 500 Tablet", "metformin", "500mg"),
    ("Crocin 500 Tablet", "paracetamol", "500mg"),
    ("Dolo 650", "paracetamol", "650mg"),
    ("Pan-40", "pantoprazole", "40mg"),
    ("Pan 40 Tab", "pantoprazole", "40mg"),          # abbreviation
    ("Telma 40", "telmisartan", "40mg"),
    ("Azithral-500", "azithromycin", "500mg"),
    ("Glycomet-SR 500", "metformin", "500mg"),
    ("Telma40", "telmisartan", "40mg"),              # no space brand/number
    ("Glycomet-GP 2 Tablet", "glimepiride+metformin", None),  # combo stays combo
]

# queries that must NEVER resolve to the WRONG drug (None = either miss, or match
# only the correct drug if present)
MUST_NOT_MISMATCH = [
    ("Vitamin C Chewable", "vitamin"),   # may match a Vitamin C product, but never Vitamin A/B/D
    ("Xyzqwer 500", None),               # junk -> must be NOT FOUND
    ("random text here", None),          # junk -> must be NOT FOUND
]


def main():
    if not DB_PATH.exists():
        sys.exit(f"DB not found: {DB_PATH} (run code/ingest.py first)")
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row

    failures = 0
    for q, salt, strength in SHOULD_MATCH:
        m = find_alternatives(conn, q)["matched"]
        if not m:
            print(f"  MISS   {q!r}  (expected {salt} {strength})")
            failures += 1
        elif m["salt"] != salt or (strength and m["strength"] != strength):
            print(f"  WRONG  {q!r} -> {m['name']!r} [{m['salt']} {m['strength']}]")
            failures += 1
        else:
            print(f"  ok     {q!r} -> {m['name']!r} ({m['match_type']})")

    for q, must_contain in MUST_NOT_MISMATCH:
        m = find_alternatives(conn, q)["matched"]
        if m is None:
            print(f"  ok     {q!r} -> NOT FOUND")
        elif must_contain and must_contain in m["salt"]:
            print(f"  ok     {q!r} -> {m['name']!r} [{m['salt']}] (right family)")
        else:
            print(f"  UNSAFE {q!r} -> {m['name']!r} [{m['salt']}]")
            failures += 1

    print(f"\n{'FAIL' if failures else 'PASS'}: {failures} failure(s)")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()

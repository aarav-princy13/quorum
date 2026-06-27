#!/usr/bin/env python3
"""Coverage report: run the real gold-receipt line items through the matcher and
show what matches, what misses, and (for misses) whether the salt composition
exists in the catalog — i.e. whether a brand ALIAS would fix it.

This operationalises "add brand aliases as real receipts surface them": run it
after adding a receipt to ocr_bench/gold/, and any miss whose composition IS
present is an alias candidate (add to _BRAND_ALIASES, then it shows as matched).

  python3 code/check_coverage.py

Informational (always exits 0) — the pass/fail guard is code/test_matching.py.
"""

import glob
import json
import sqlite3
import sys
from pathlib import Path

CODE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(CODE_DIR))
DB = CODE_DIR.parent / "data" / "b2g.db"
GOLD = CODE_DIR / "ocr_bench" / "gold"

from b2g.matcher import find_alternatives  # noqa: E402


def main():
    if not DB.exists():
        print(f"DB not found: {DB} (build it first)")
        return 0
    conn = sqlite3.connect(str(DB))
    conn.row_factory = sqlite3.Row

    matched = misses = 0
    miss_rows = []
    for f in sorted(glob.glob(str(GOLD / "*.json"))):
        g = json.load(open(f, encoding="utf-8"))
        for it in g["items"]:
            res = find_alternatives(conn, it["name"])
            if res["matched"]:
                matched += 1
            else:
                misses += 1
                miss_rows.append((g["receipt"], it["name"]))

    total = matched + misses
    print(f"Matched {matched}/{total} real line items "
          f"({100*matched/total:.0f}%) across {len(glob.glob(str(GOLD/'*.json')))} receipts\n")
    if miss_rows:
        print("Misses (a real medicine here that we can't match is a coverage gap;")
        print("generic descriptions / homeopathy / packaging are expected misses):")
        for rc, name in miss_rows:
            print(f"  {rc:8} {name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Regression tests for the receipt pipeline's savings math (qty semantics).

The bar is PRECISION: a wrong OVERSTATEMENT of savings is worse than an
undercount. So savings scale with the number of UNITS bought at the per-unit
price gap — never per pack (which would multiply by pack size). When the receipt
gives no qty, we estimate one pack's worth (the realistic minimum), never more.

Run (after building data/b2g.db):  python3 code/test_pipeline.py
Exits non-zero if any case regresses.
"""

import sqlite3
import sys
from pathlib import Path

CODE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(CODE_DIR))
DB_PATH = CODE_DIR.parent / "data" / "b2g.db"

from b2g.pipeline import process_receipt  # noqa: E402

NAME = "Telma 40 Tablet"  # a well-populated salt so alternatives exist


def main():
    if not DB_PATH.exists():
        print(f"DB missing at {DB_PATH} — build it first (see session_transfer §11)")
        return 1
    conn = sqlite3.connect(str(DB_PATH))
    conn.row_factory = sqlite3.Row

    fails = []

    def check(desc, cond):
        print(f"  {'ok' if cond else 'FAIL'}   {desc}")
        if not cond:
            fails.append(desc)

    # Known qty (units): line == per_unit * qty, exactly.
    one = process_receipt(conn, [{"name": NAME, "qty": 30}])["items"][0]
    per_unit = one["savings_inr_per_unit"]
    units = one["matched"]["units"] or 1
    check("matched with a per-unit saving (fixture sanity)", per_unit > 0)
    check("known qty: line == per_unit * qty",
          one["savings_inr_line"] == round(per_unit * 30, 2))
    check("known qty: NOT per-pack * qty (the overstatement bug)",
          one["savings_inr_line"] != round(one["savings_inr_pack"] * 30, 2))

    # Unknown qty (omitted): falls back to one pack's worth, never more.
    none = process_receipt(conn, [{"name": NAME}])["items"][0]
    check("unknown qty: reported qty falls back to pack units",
          none["qty"] == int(units))
    check("unknown qty: line == one pack (per_unit * units)",
          none["savings_inr_line"] == round(per_unit * units, 2))
    check("unknown qty never exceeds the same item at known qty=units",
          none["savings_inr_line"] <= round(per_unit * units, 2) + 0.01)

    # Total scales with units, not packs.
    total = process_receipt(conn, [{"name": NAME, "qty": 30}])["summary"]["total_savings_inr"]
    check("summary total == the line savings", total == one["savings_inr_line"])

    print(f"\n{'PASS' if not fails else 'FAIL'}: {len(fails)} failure(s)")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())

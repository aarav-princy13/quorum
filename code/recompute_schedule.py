#!/usr/bin/env python3
"""Re-derive the drugs.schedule column from the current curated salt lists
(b2g/schedule.py), WITHOUT a full re-ingest. Run this after editing the salt sets.

  python3 code/recompute_schedule.py

Stdlib only. Safe to run while the API server is up (it opens read-only; this is
the single writer, and each API request reopens the DB so it sees the new values).
"""

import sqlite3
import sys
from collections import Counter
from pathlib import Path

CODE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(CODE_DIR))
DB = CODE_DIR.parent / "data" / "b2g.db"

from b2g.schedule import schedule_for  # noqa: E402


def main():
    if not DB.exists():
        sys.exit(f"DB not found: {DB} (build it with code/ingest.py first)")
    conn = sqlite3.connect(DB)
    conn.row_factory = sqlite3.Row
    before = Counter(r[0] for r in conn.execute("SELECT schedule FROM drugs"))

    updates = []
    for r in conn.execute("SELECT id, salt, form, schedule FROM drugs"):
        new = schedule_for(r["salt"], r["form"])
        if new != (r["schedule"] or ""):
            updates.append((new, r["id"]))

    conn.executemany("UPDATE drugs SET schedule=? WHERE id=?", updates)
    conn.commit()
    after = Counter(r[0] for r in conn.execute("SELECT schedule FROM drugs"))
    conn.close()

    print(f"updated {len(updates)} rows")
    print("schedule  before -> after")
    for code in ["", "H", "H1", "X"]:
        label = code or "(OTC)"
        print(f"  {label:5} {before.get(code, 0):7d} -> {after.get(code, 0):7d}")


if __name__ == "__main__":
    main()

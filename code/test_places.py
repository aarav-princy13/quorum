#!/usr/bin/env python3
"""Tests for Overpass parsing (b2g.places.parse_overpass) — pure, no network.

Guards distance ranking, the `limit`, Jan Aushadhi classification, and skipping
elements without coordinates.

Run:  python3 code/test_places.py
"""

import sys
from pathlib import Path

CODE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(CODE_DIR))

from b2g.places import parse_overpass  # noqa: E402

# A point in Chandigarh; elements at increasing distances + one JA kendra + one
# coordinate-less node that must be dropped.
LAT, LON = 30.7333, 76.7794
PAYLOAD = {
    "elements": [
        {"id": 1, "lat": 30.9000, "lon": 76.9000, "tags": {"name": "Far Chemist"}},
        {"id": 2, "lat": 30.7340, "lon": 76.7800,
         "tags": {"name": "Pradhan Mantri Jan Aushadhi Kendra", "addr:city": "Chandigarh"}},
        {"id": 3, "lat": 30.7360, "lon": 76.7810, "tags": {"name": "Near Medicos"}},
        {"id": 4, "tags": {"name": "No Coords Pharmacy"}},          # dropped (no lat/lon)
        {"id": 5, "lat": 30.7335, "lon": 76.7795, "tags": {}},      # unnamed
    ],
}


def main():
    rows = parse_overpass(PAYLOAD, LAT, LON, limit=3)
    fails = []

    def check(desc, cond):
        print(f"  {'ok' if cond else 'FAIL'}   {desc}")
        if not cond:
            fails.append(desc)

    check("limit applied (3 of 4 located)", len(rows) == 3)
    check("coordinate-less element dropped",
          all(r["name"] != "No Coords Pharmacy" for r in rows))
    check("distance-ranked ascending",
          [r["distance_km"] for r in rows] == sorted(r["distance_km"] for r in rows))
    check("nearest is the unnamed node at ~30.7335",
          rows[0]["name"] == "Pharmacy (unnamed)")
    ja = next((r for r in rows if "Aushadhi" in r["name"]), None)
    check("Jan Aushadhi kendra classified", ja is not None and ja["kind"] == "jan_aushadhi")
    check("Far Chemist excluded by limit",
          all(r["name"] != "Far Chemist" for r in rows))

    print(f"\n{'PASS' if not fails else 'FAIL'}: {len(fails)} failure(s)")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())

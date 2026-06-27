#!/usr/bin/env python3
"""Populate the pharmacies table with REAL locations from OpenStreetMap (Overpass).

Neutral by design: we list *any* nearby pharmacy (the app's wedge is finding cheaper
generics at whatever shop is closest), and tag Jan Aushadhi Kendras specially.

Run after the base DB exists:
  python3 code/ingest_pharmacies.py                 # default: Chandigarh, 16 km
  python3 code/ingest_pharmacies.py 19.0760 72.8777 12   # lat lon radius_km

Pure standard library: urllib, json, sqlite3. No third-party deps.

NOTE: as of 2026-06-27 the API queries OpenStreetMap (Overpass) LIVE per request
(b2g/places.py) — real, current, global pharmacies. This static snapshot is now only
the OFFLINE FALLBACK used when Overpass is unreachable, so it need not be comprehensive.
OSM pharmacy coverage in India is sparse (many shops unmapped); production would use a
managed Places API or the Jan Aushadhi Kendra directory for fuller coverage.
"""

import json
import sqlite3
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

CODE_DIR = Path(__file__).resolve().parent
DB_PATH = CODE_DIR.parent / "data" / "b2g.db"
RAW = CODE_DIR.parent / "data" / "raw" / "osm_pharmacies.json"
OVERPASS = "https://overpass-api.de/api/interpreter"
UA = "brand_to_generic/0.1 (research prototype; contact: aarav10a1@gmail.com)"

# tricity Chandigarh default
DEF_LAT, DEF_LON, DEF_RADIUS_KM = 30.7333, 76.7794, 16.0


def fetch_overpass(lat, lon, radius_m, retries=4):
    """POST an Overpass query for pharmacy nodes; retry on the mirror's rate limits."""
    query = (f"[out:json][timeout:60];"
             f'node["amenity"="pharmacy"](around:{radius_m},{lat},{lon});out body;')
    data = urllib.parse.urlencode({"data": query}).encode()
    last = ""
    for attempt in range(retries):
        try:
            req = urllib.request.Request(
                OVERPASS, data=data,
                headers={"User-Agent": UA, "Accept": "application/json"})
            with urllib.request.urlopen(req, timeout=90) as resp:
                body = resp.read().decode("utf-8", "replace")
            return json.loads(body)
        except Exception as e:                       # network / rate-limit / non-JSON
            last = str(e)
            time.sleep(3 * (attempt + 1))            # linear backoff
    raise SystemExit(f"Overpass fetch failed after {retries} tries: {last}")


def classify(tags):
    blob = (tags.get("name", "") + " " + tags.get("operator", "")).lower()
    if "aushadhi" in blob or "janaushadhi" in blob:
        return "jan_aushadhi"
    if "generic" in blob:
        return "generic"
    return "retail"


def main():
    argv = sys.argv[1:]
    lat = float(argv[0]) if len(argv) > 0 else DEF_LAT
    lon = float(argv[1]) if len(argv) > 1 else DEF_LON
    radius_m = int(float(argv[2]) * 1000) if len(argv) > 2 else int(DEF_RADIUS_KM * 1000)

    if not DB_PATH.exists():
        sys.exit(f"Base DB not found: {DB_PATH}\nRun `python3 code/ingest.py` first.")

    payload = fetch_overpass(lat, lon, radius_m)
    RAW.parent.mkdir(parents=True, exist_ok=True)
    RAW.write_text(json.dumps(payload), encoding="utf-8")
    elements = payload.get("elements", [])

    rows = []
    for e in elements:
        if "lat" not in e or "lon" not in e:
            continue
        tags = e.get("tags", {})
        name = tags.get("name") or "Pharmacy (unnamed)"
        area = tags.get("addr:suburb") or tags.get("addr:neighbourhood") or tags.get("addr:city") or ""
        city = tags.get("addr:city") or ""
        rows.append((name, classify(tags), city, area, e["lat"], e["lon"],
                     "openstreetmap", e.get("id")))

    conn = sqlite3.connect(DB_PATH)
    conn.execute("DELETE FROM pharmacies")           # replace seed/previous
    conn.executemany(
        "INSERT INTO pharmacies (name,kind,city,area,lat,lon,source,osm_id) "
        "VALUES (?,?,?,?,?,?,?,?)", rows)
    conn.commit()
    n_named = sum(1 for r in rows if not r[0].startswith("Pharmacy (unnamed"))
    n_ja = sum(1 for r in rows if r[1] == "jan_aushadhi")
    print(f"OSM pharmacies near ({lat},{lon}) r={radius_m/1000:.0f}km: "
          f"inserted {len(rows)} ({n_named} named, {n_ja} Jan Aushadhi)")
    conn.close()


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Ingest the Indian Medicine Dataset (~254k rows) into a SQLite catalog.

Source (download first, stdlib-friendly, ~32 MB):
  mkdir -p data/raw && curl -L -o data/raw/indian_medicine_data.csv \\
    https://raw.githubusercontent.com/junioralive/Indian-Medicine-Dataset/main/DATA/indian_medicine_data.csv

Then:  python3 code/ingest.py            # builds data/b2g.db

Source fields: id, name, price(₹), Is_discontinued, manufacturer_name, type,
pack_size_label, short_composition1, short_composition2.

LICENSE NOTE: this dataset's license is unspecified upstream — treat as PROTOTYPE
data and verify rights before any commercial use (see writeup/DATA_SOURCES.md).
Pure standard library: csv, sqlite3, re. No pandas.
"""

import csv
import re
import sqlite3
import sys
from pathlib import Path

CODE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(CODE_DIR))
ROOT = CODE_DIR.parent
RAW_CSV = ROOT / "data" / "raw" / "indian_medicine_data.csv"
DB_PATH = ROOT / "data" / "b2g.db"

from b2g.matcher import normalize                        # noqa: E402
from b2g.schedule import schedule_for                     # noqa: E402
from b2g.util import parse_pack_units                     # noqa: E402
from b2g.normalize import canonical_salt, canonical_strength  # noqa: E402

_PAREN_RE = re.compile(r"\(([^)]*)\)")

_INSERT = ("INSERT INTO drugs (name,name_norm,salt,strength,strength_known,form,"
           "mrp_inr,pack,units,unit_price,is_generic,schedule,source) "
           "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)")


def parse_component(raw):
    """Split one composition cell into (salt, strength). Returns None if empty.

    Robust to multiple parens: salt = text before the first '(', strength = the
    LAST parenthesized group, e.g. "Cholecalciferol (Vitamin D3) (1000IU)" ->
    ("cholecalciferol", "1000IU").
    """
    raw = (raw or "").strip()
    if not raw:
        return None
    groups = _PAREN_RE.findall(raw)
    salt = re.sub(r"\s+", " ", re.split(r"\(", raw, 1)[0]).strip().lower()
    strength = groups[-1].strip().lower() if groups else ""
    return (salt, strength) if salt else None


def composition_key(c1, c2):
    """Build canonical (salt, strength, strength_known) for a product.

    Salts/strengths are canonicalized (b2g.normalize) and components sorted by
    salt so "A+B" and "B+A" collapse to one key. strength_known is False if ANY
    component lacks a real (digit-bearing) dose.
    """
    comps = [c for c in (parse_component(c1), parse_component(c2)) if c]
    if not comps:
        return None
    known = True
    norm = []
    for salt, strength in comps:
        cs = canonical_salt(salt)
        cst = canonical_strength(strength)
        if not cst:
            known = False
        norm.append((cs, cst))
    norm.sort(key=lambda cs: cs[0])
    salt = "+".join(s for s, _ in norm)
    strength = "+".join(st for _, st in norm)
    return salt, strength, known


def detect_form(name, pack):
    blob = f"{name} {pack}".lower()
    for form in ("syrup", "injection", "capsule", "tablet", "drops", "cream",
                 "gel", "ointment", "suspension", "powder", "inhaler", "solution"):
        if form in blob:
            return form
    return ""


def to_float(s):
    try:
        return round(float(str(s).replace(",", "").strip()), 2)
    except (ValueError, TypeError):
        return None


def main():
    if not RAW_CSV.exists():
        sys.exit(f"Raw CSV not found: {RAW_CSV}\nDownload it first (see this file's docstring).")

    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    if DB_PATH.exists():
        DB_PATH.unlink()  # rebuild from scratch
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.executescript((CODE_DIR / "schema.sql").read_text(encoding="utf-8"))

    # PMBJP Jan Aushadhi Kendras (sample) so nearby-pharmacy lookup still works.
    seed_ph = CODE_DIR / "seed_data" / "pharmacies.csv"
    with open(seed_ph, newline="", encoding="utf-8") as fh:
        ph = [(r["name"], r["kind"], r["city"], r["area"], r["lat"], r["lon"])
              for r in csv.DictReader(fh)]
    conn.executemany(
        "INSERT INTO pharmacies (name, kind, city, area, lat, lon) VALUES (?,?,?,?,?,?)", ph)

    read = inserted = skipped_disc = skipped_nocomp = 0
    batch = []
    with open(RAW_CSV, newline="", encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        price_col = next(c for c in reader.fieldnames if c.startswith("price"))
        for row in reader:
            read += 1
            if str(row.get("Is_discontinued", "")).strip().upper() == "TRUE":
                skipped_disc += 1
                continue
            key = composition_key(row.get("short_composition1"), row.get("short_composition2"))
            if key is None:
                skipped_nocomp += 1
                continue
            salt, strength, known = key
            name = (row.get("name") or "").strip()
            pack = (row.get("pack_size_label") or "").strip()
            mrp = to_float(row.get(price_col))
            units = parse_pack_units(pack)
            unit_price = round(mrp / units, 4) if (mrp and units) else mrp
            form = detect_form(name, pack)
            sched = schedule_for(salt, form)
            is_generic = 1 if normalize(name).startswith(salt.split("+")[0][:6]) else 0
            batch.append((
                name, normalize(name), salt, strength, 1 if known else 0,
                form, mrp, pack, units, unit_price,
                is_generic, sched, "indian-medicine-dataset",
            ))
            if len(batch) >= 5000:
                conn.executemany(_INSERT, batch)
                inserted += len(batch)
                batch.clear()
    if batch:
        conn.executemany(_INSERT, batch)
        inserted += len(batch)
    conn.commit()

    n_comp = conn.execute("SELECT COUNT(DISTINCT salt || '|' || strength) FROM drugs").fetchone()[0]
    n_flag = conn.execute("SELECT COUNT(*) FROM drugs WHERE schedule != ''").fetchone()[0]
    n_unk = conn.execute("SELECT COUNT(*) FROM drugs WHERE strength_known = 0").fetchone()[0]
    print(f"read {read} rows -> inserted {inserted}"
          f" (skipped {skipped_disc} discontinued, {skipped_nocomp} no-composition)")
    print(f"distinct compositions: {n_comp} · schedule-flagged: {n_flag}"
          f" · unknown-dose (not offered as substitutes): {n_unk}")
    print(f"DB: {DB_PATH} ({DB_PATH.stat().st_size // (1024*1024)} MB)")
    conn.close()


if __name__ == "__main__":
    main()

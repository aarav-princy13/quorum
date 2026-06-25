#!/usr/bin/env python3
"""Ingest the OFFICIAL Jan Aushadhi (PMBJP) generic price list as authoritative rows.

Source: the public JSON API behind janaushadhi.gov.in's "Product MRP" page.
Fetch once (stdlib-friendly; the API lives on port 8443 and wants a POST):

  curl -s -X POST -H 'Content-Type: application/json' -H 'Referer: https://janaushadhi.gov.in/' \\
    -d '{"pageIndex":0,"pageSize":3000,"searchText":"","orderBy":"asc","columnName":"genericName"}' \\
    'https://janaushadhi.gov.in:8443/api/v1/admin/product/getAllProductForWeb' \\
    -o data/raw/janaushadhi_products.json

Then (after code/ingest.py has built the base catalog):
  python3 code/ingest_janaushadhi.py

These rows are official PMBJP prices -> is_authoritative=1, is_generic=1,
source='janaushadhi'. Pure stdlib: json, sqlite3, re.
"""

import json
import re
import sqlite3
import sys
from pathlib import Path

CODE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(CODE_DIR))
ROOT = CODE_DIR.parent
SRC = ROOT / "data" / "raw" / "janaushadhi_products.json"
DB_PATH = ROOT / "data" / "b2g.db"

from b2g.matcher import normalize                          # noqa: E402
from b2g.schedule import schedule_for                      # noqa: E402
from b2g.util import parse_pack_units                      # noqa: E402
from b2g.normalize import canonical_salt, canonical_strength  # noqa: E402

# dosage-form keyword -> canonical form (kept consistent with ingest.detect_form)
_FORMS = [
    ("tablets", "tablet"), ("tablet", "tablet"), ("capsules", "capsule"),
    ("capsule", "capsule"), ("injections", "injection"), ("injection", "injection"),
    ("infusion", "injection"), ("oral solution", "solution"), ("solution", "solution"),
    ("oral suspension", "suspension"), ("suspension", "suspension"), ("syrup", "syrup"),
    ("eye drops", "drops"), ("ear drops", "drops"), ("drops", "drops"), ("cream", "cream"),
    ("ointment", "ointment"), ("gel", "gel"), ("lotion", "lotion"), ("powder", "powder"),
    ("granules", "powder"), ("sachet", "powder"), ("inhaler", "inhaler"),
    ("respirator solution", "solution"), ("spray", "spray"), ("lozenges", "lozenges"),
    ("suppositories", "suppository"), ("suppository", "suppository"),
]

# a single dose token, optionally a ratio "/5ml"
_DOSE = re.compile(
    r"\d+(?:\.\d+)?\s*(?:mcg|mg|gm|g|iu|ml|%)(?:\s*/\s*\d+(?:\.\d+)?\s*ml)?", re.I)
_QUALIFIER_WORDS = re.compile(r"\b(ip|bp|usp|i\.p\.|b\.p\.|prolonged release|sustained release|"
                              r"extended release|gastro.?resistant|sr|er|xr|cr|dispersible|dt|"
                              r"film coated|enteric coated|chewable|effervescent)\b", re.I)
# all dosage-form words (longest first) for removal from the working string
_FORM_RE = re.compile(
    r"\b(?:" + "|".join(kw.replace(" ", r"\s+") for kw in
                        sorted({k for k, _ in _FORMS}, key=len, reverse=True)) + r")\b", re.I)
_SPLIT_RE = re.compile(r"\s+and\s+|\s*\+\s*|\s*&\s*", re.I)


def parse_generic_name(gname):
    """Parse a PMBJP genericName -> (salt, strength, form, strength_known).

    Splits the name into salt+dose segments so combinations keep salt/dose
    ALIGNED (e.g. "Telmisartan 40mg and Chlorthalidone 12.5mg" ->
    salt "chlorthalidone+telmisartan", strength "12.5mg+40mg"), matching the
    open dataset's sorted-by-salt composition key.
    """
    low = " ".join(gname.split()).lower()

    form = ""
    for kw, canon in _FORMS:
        if re.search(rf"\b{kw.replace(' ', r'[ ]+')}\b", low):
            form = canon
            break

    work = re.sub(r"\(.*?\)", " ", low).replace(" per ", "/")   # drop parens, ratio "per"->"/"
    work = _QUALIFIER_WORDS.sub(" ", work)
    work = _FORM_RE.sub(" ", work)

    # doses and salts in LISTED ORDER, then pair positionally (works for both
    # "SaltA 40mg and SaltB 12.5mg" and "SaltA and SaltB 500mg+125mg").
    doses = [d for d in (canonical_strength(m.group(0)) for m in _DOSE.finditer(work)) if d]
    salts = [s for s in (canonical_salt(x) for x in _SPLIT_RE.split(_DOSE.sub(" ", work))) if s]
    if not salts:
        return "", "", form, False

    if len(salts) == len(doses):
        pairs = list(zip(salts, doses))
    elif len(salts) == 1:
        pairs = [(salts[0], doses[-1] if doses else "")]
    else:
        pairs = [(s, "") for s in salts]          # can't align -> strengths unknown (safe)

    pairs.sort(key=lambda p: p[0])
    salt = "+".join(s for s, _ in pairs)
    strength = "+".join(st for _, st in pairs)
    known = bool(pairs) and all(st for _, st in pairs)
    return salt, strength, form, known


def main():
    if not SRC.exists():
        sys.exit(f"Source not found: {SRC}\nFetch it first (see this file's docstring).")
    if not DB_PATH.exists():
        sys.exit(f"Base DB not found: {DB_PATH}\nRun `python3 code/ingest.py` first.")

    products = json.load(open(SRC, encoding="utf-8"))["responseBody"]["newProductResponsesList"]
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("DELETE FROM drugs WHERE source = 'janaushadhi'")   # idempotent

    rows, no_strength, no_form, no_price = [], 0, 0, 0
    for p in products:
        gname = (p.get("genericName") or "").strip()
        mrp = p.get("mrp")
        unit = p.get("unitSize") or ""
        if not mrp or mrp <= 0:          # skip unpriced rows (mrp 0.0 / null)
            no_price += 1
            continue
        salt, strength, form, known = parse_generic_name(gname)
        if not salt:
            continue
        if not strength:
            no_strength += 1
        if not form:
            no_form += 1
        units = parse_pack_units(unit)
        unit_price = round(mrp / units, 4) if (mrp and units) else mrp
        rows.append((
            gname, normalize(gname), salt, strength, 1 if known else 0, form, mrp, unit,
            units, unit_price, 1, 1, schedule_for(salt, form), "janaushadhi",
        ))

    conn.executemany(
        "INSERT INTO drugs (name,name_norm,salt,strength,strength_known,form,mrp_inr,"
        "pack,units,unit_price,is_generic,is_authoritative,schedule,source) "
        "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)", rows)
    conn.commit()

    # coverage: how many authoritative rows share a composition+form with open-dataset brands?
    covered = conn.execute(
        "SELECT COUNT(*) FROM drugs a WHERE a.source='janaushadhi' AND a.strength_known=1 "
        "AND EXISTS (SELECT 1 FROM drugs b WHERE b.source!='janaushadhi' "
        "AND b.salt=a.salt AND b.strength=a.strength AND b.form=a.form)").fetchone()[0]
    print(f"Jan Aushadhi: parsed {len(rows)}/{len(products)} priced products "
          f"({no_price} unpriced skipped, {no_strength} without a strength, {no_form} without a form)")
    print(f"authoritative rows that match an existing brand composition+form: {covered}")
    print(f"DB: {DB_PATH}")
    conn.close()


if __name__ == "__main__":
    main()

"""Match a scanned brand name to its composition, then find cheaper equivalents.

Matching here is deliberately simple (exact + normalized + leading-token). Real OCR
output is fuzzy; robust fuzzy matching is a later task (see writeup/TODO.md).
"""

import re
import statistics

# Ignore same-composition products priced below this fraction of the median
# per-unit price — almost always data-entry errors in the open dataset
# (e.g. per-tablet price entered as a per-strip price). Tunable.
OUTLIER_FLOOR_FRAC = 0.2


def normalize(text):
    """Lowercase, collapse whitespace, strip punctuation — for tolerant name matching."""
    text = (text or "").lower().strip()
    text = re.sub(r"[^a-z0-9+ ]+", " ", text)   # keep '+' for salt combinations
    return re.sub(r"\s+", " ", text).strip()


def _lookup_drug(conn, name):
    """Find the catalog row for a scanned name via the indexed name_norm column.

    Tries, in order: (1) exact normalized match, (2) a catalog name that is a
    prefix of the query ("crocin 500 tablet" -> "crocin 500"), (3) the query as a
    prefix of a catalog name. Returns a sqlite3.Row or None.
    """
    norm = normalize(name)

    # 1) exact normalized match (uses idx_drugs_name_norm); cheapest if duplicates
    row = conn.execute(
        "SELECT * FROM drugs WHERE name_norm = ? ORDER BY mrp_inr LIMIT 1", (norm,)
    ).fetchone()
    if row:
        return row

    # 2) a stored name_norm is a leading prefix of the query -> most specific wins
    row = conn.execute(
        "SELECT * FROM drugs WHERE name_norm = substr(?, 1, length(name_norm)) "
        "AND length(name_norm) >= 3 ORDER BY length(name_norm) DESC, mrp_inr LIMIT 1",
        (norm,),
    ).fetchone()
    if row:
        return row

    # 3) the query is a prefix of a stored name (index-friendly: no leading wildcard)
    row = conn.execute(
        "SELECT * FROM drugs WHERE name_norm LIKE ? ESCAPE '\\' "
        "ORDER BY length(name_norm) ASC, mrp_inr LIMIT 1",
        (norm.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_") + " %",),
    ).fetchone()
    return row


def _row_unit_price(row):
    """Per-unit price, falling back to pack MRP when units are unknown."""
    up = row["unit_price"]
    return up if up is not None else row["mrp_inr"]


def find_alternatives(conn, name):
    """For a scanned brand name, return its match + cheaper equivalents.

    Equivalents must share the SAME composition (salt + strength) AND the SAME
    dosage form (a tablet is not swapped for an injection), and are compared on
    PER-UNIT price so unlike pack sizes are judged fairly.

    Returns a dict with: matched, alternatives (cheapest-first), cheapest,
    savings_per_unit / savings_pct / savings_pack (savings for one matched-pack).
    """
    matched = _lookup_drug(conn, name)
    if matched is None:
        return {"query": name, "matched": None, "alternatives": [], "cheapest": None}

    m_unit = _row_unit_price(matched)

    # Pull every same-composition, same-form product (to compute a robust price
    # floor and to count real alternatives), then filter in Python.
    # strength_known = 1 excludes products whose dose we couldn't verify — never
    # recommend a substitute when we don't know its strength.
    sql = ("SELECT * FROM drugs WHERE salt = ? AND strength = ? AND strength_known = 1 "
           "AND COALESCE(unit_price, mrp_inr) IS NOT NULL ")
    params = [matched["salt"], matched["strength"]]
    if matched["form"]:
        sql += "AND form = ? "
        params.append(matched["form"])
    candidates = conn.execute(sql, params).fetchall()

    # Outlier floor: drop implausibly-cheap data errors below a fraction of the median.
    prices = [_row_unit_price(r) for r in candidates]
    floor = 0.0
    n_outliers = 0
    if len(prices) >= 5:
        floor = OUTLIER_FLOOR_FRAC * statistics.median(prices)
        n_outliers = sum(1 for p in prices if p < floor)

    # Authoritative (official Jan Aushadhi/NPPA) prices are verified-correct, so they
    # are EXEMPT from the outlier floor — govt-subsidized prices are genuinely low.
    cheaper = [
        r for r in candidates
        if r["id"] != matched["id"] and _row_unit_price(r) < m_unit
        and (_row_unit_price(r) >= floor or r["is_authoritative"])
    ]
    cheaper.sort(key=_row_unit_price)

    def to_dict(r):
        return {
            "name": r["name"],
            "mrp_inr": r["mrp_inr"],
            "unit_price": _row_unit_price(r),
            "units": r["units"],
            "is_generic": bool(r["is_generic"]),
            "is_authoritative": bool(r["is_authoritative"]),
            "source": r["source"],
            "pack": r["pack"],
        }

    alternatives = [to_dict(r) for r in cheaper[:25]]
    cheapest = alternatives[0] if alternatives else None
    # Cheapest option backed by an official price (Jan Aushadhi/NPPA) — a trusted anchor.
    # Computed over the FULL cheaper list (not the top-25) so an official price that
    # ranks below many cheap generics is still surfaced.
    auth_row = next((r for r in cheaper if r["is_authoritative"]), None)
    cheapest_authoritative = to_dict(auth_row) if auth_row else None

    result = {
        "query": name,
        "matched": {
            "name": matched["name"],
            "salt": matched["salt"],
            "strength": matched["strength"],
            "form": matched["form"],
            "mrp_inr": matched["mrp_inr"],
            "unit_price": m_unit,
            "units": matched["units"],
            "schedule": matched["schedule"],
            "pack": matched["pack"],
        },
        "alternatives": alternatives,
        "cheapest": cheapest,
        "cheapest_authoritative": cheapest_authoritative,
        "n_alternatives": len(cheaper),
        "n_outliers_excluded": n_outliers,
    }
    if cheapest and m_unit:
        per_unit = m_unit - cheapest["unit_price"]
        pack_units = matched["units"] or 1
        result["savings_per_unit"] = round(per_unit, 2)
        result["savings_pct"] = round(100 * per_unit / m_unit, 1)
        result["savings_pack"] = round(per_unit * pack_units, 2)   # buy one matched-pack worth, cheaper
    else:
        result["savings_per_unit"] = 0.0
        result["savings_pct"] = 0.0
        result["savings_pack"] = 0.0
    return result

"""Match a scanned brand name to its composition, then find cheaper equivalents.

Matching here is deliberately simple (exact + normalized + leading-token). Real OCR
output is fuzzy; robust fuzzy matching is a later task (see writeup/TODO.md).
"""

import difflib
import re
import statistics

# Ignore same-composition products priced below this fraction of the median
# per-unit price — almost always data-entry errors in the open dataset
# (e.g. per-tablet price entered as a per-strip price). Tunable.
OUTLIER_FLOOR_FRAC = 0.2


def normalize(text):
    """Lowercase, depunctuate, and split letter/digit runs — for tolerant matching.

    Splitting "telma40" -> "telma 40" and "500mg" -> "500 mg" makes brand, number,
    and unit separate tokens so receipt shorthand lines up with catalog names.
    """
    text = (text or "").lower().strip()
    text = re.sub(r"[^a-z0-9+ ]+", " ", text)        # keep '+' for salt combinations
    text = re.sub(r"(?<=[a-z])(?=[0-9])", " ", text)  # telma40 -> telma 40
    text = re.sub(r"(?<=[0-9])(?=[a-z])", " ", text)  # 500mg -> 500 mg
    return re.sub(r"\s+", " ", text).strip()


_NUM_RE = re.compile(r"\d+(?:\.\d+)?")
FUZZY_THRESHOLD = 0.55          # minimum blended score to accept a fuzzy match


def _name_numbers(text):
    """Numeric tokens in a name (the printed strength, e.g. {500.0}). Used as a guard."""
    return {float(x) for x in _NUM_RE.findall(text or "")}


def _discriminators(tokens):
    """Tokens that distinguish DIFFERENT drugs and must be preserved in any match:
    anything with a digit (500, 40, d3, b12) and single letters (vitamin c vs a).
    Generic words (tablet, sr, duo) are intentionally excluded."""
    out = set()
    for t in tokens:
        if any(c.isdigit() for c in t) or (len(t) == 1 and t.isalpha()):
            out.add(t)
    return out


def _esc_like(s):
    return s.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")


def _fuzzy_lookup(conn, norm):
    """Conservative fuzzy match for messy/OCR'd names.

    Blocks on the brand prefix (first token) for speed, then ranks by a blend of
    string similarity + token overlap. SAFETY: if the query has a printed strength
    number and a candidate also has one but they DISAGREE, the candidate is
    rejected — we never substitute a different strength (e.g. "Glycomet 500" must
    not match the combo "Glycomet-GP 1"). Returns (row, score) or (None, 0).
    """
    qtokens = norm.split()
    if not qtokens:
        return None, 0.0
    brand = qtokens[0]
    prefix = brand[:4] if len(brand) >= 4 else brand
    cands = conn.execute(
        "SELECT * FROM drugs WHERE name_norm LIKE ? ESCAPE '\\' LIMIT 5000",
        (_esc_like(prefix) + "%",),
    ).fetchall()
    if not cands:
        return None, 0.0

    qtok = set(qtokens)
    qdisc = _discriminators(qtokens)
    best, best_score = None, 0.0
    for r in cands:
        cn = r["name_norm"] or ""
        ctok = set(cn.split())
        # SAFETY: every distinguishing token (strength, vitamin letter, ...) must be
        # present in the candidate — blocks "Vitamin C"->"Vitamin A", "500"->"1gm", etc.
        if not qdisc.issubset(ctok):
            continue
        ratio = difflib.SequenceMatcher(None, norm, cn).ratio()
        jacc = len(qtok & ctok) / len(qtok | ctok) if (qtok | ctok) else 0.0
        score = 0.6 * ratio + 0.4 * jacc
        if score > best_score:
            best, best_score = r, score
    return (best, best_score) if best_score >= FUZZY_THRESHOLD else (None, best_score)


def _lookup_drug(conn, name):
    """Find the catalog row for a scanned name. Returns (row, match_type).

    Order: (1) exact normalized, (2) catalog name is a prefix of the query,
    (3) query is a prefix of a catalog name, (4) conservative fuzzy match.
    match_type is one of 'exact' | 'prefix' | 'fuzzy' | None.
    """
    norm = normalize(name)

    row = conn.execute(
        "SELECT * FROM drugs WHERE name_norm = ? ORDER BY mrp_inr LIMIT 1", (norm,)
    ).fetchone()
    if row:
        return row, "exact"

    row = conn.execute(
        "SELECT * FROM drugs WHERE name_norm = substr(?, 1, length(name_norm)) "
        "AND length(name_norm) >= 3 ORDER BY length(name_norm) DESC, mrp_inr LIMIT 1",
        (norm,),
    ).fetchone()
    if row:
        return row, "prefix"

    row = conn.execute(
        "SELECT * FROM drugs WHERE name_norm LIKE ? ESCAPE '\\' "
        "ORDER BY length(name_norm) ASC, mrp_inr LIMIT 1",
        (_esc_like(norm) + " %",),
    ).fetchone()
    if row:
        return row, "prefix"

    row, _score = _fuzzy_lookup(conn, norm)
    return (row, "fuzzy") if row else (None, None)


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
    matched, match_type = _lookup_drug(conn, name)
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
            "match_type": match_type,
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

"""Match a scanned brand name to its composition, then find cheaper equivalents.

Matching here is deliberately simple (exact + normalized + leading-token). Real OCR
output is fuzzy; robust fuzzy matching is a later task (see writeup/TODO.md).
"""

import re


def normalize(text):
    """Lowercase, collapse whitespace, strip punctuation — for tolerant name matching."""
    text = (text or "").lower().strip()
    text = re.sub(r"[^a-z0-9+ ]+", " ", text)   # keep '+' for salt combinations
    return re.sub(r"\s+", " ", text).strip()


def _lookup_drug(conn, name):
    """Find the catalog row for a scanned name. Returns a sqlite3.Row or None."""
    norm = normalize(name)

    # 1) exact normalized match
    for row in conn.execute("SELECT * FROM drugs"):
        if normalize(row["name"]) == norm:
            return row

    # 2) prefix / leading-token match (e.g. "Crocin 500 Tab" -> "Crocin 500")
    candidates = []
    for row in conn.execute("SELECT * FROM drugs"):
        rnorm = normalize(row["name"])
        if norm.startswith(rnorm) or rnorm.startswith(norm):
            candidates.append((len(rnorm), row))
    if candidates:
        candidates.sort(reverse=True)          # prefer the longest (most specific) match
        return candidates[0][1]
    return None


def find_alternatives(conn, name):
    """For a scanned brand name, return its match + cheaper same-composition options.

    Returns a dict:
      matched   : the catalog row we identified (or None)
      salt/strength
      alternatives : list of {name, mrp_inr, is_generic, source, pack} cheaper than `matched`,
                     sorted cheapest-first
      cheapest  : the single cheapest alternative (or None)
      savings_inr / savings_pct : vs the matched product's MRP
    """
    matched = _lookup_drug(conn, name)
    if matched is None:
        return {"query": name, "matched": None, "alternatives": [], "cheapest": None}

    rows = conn.execute(
        "SELECT * FROM drugs WHERE salt = ? AND strength = ? AND id != ? "
        "AND mrp_inr < ? ORDER BY mrp_inr ASC",
        (matched["salt"], matched["strength"], matched["id"], matched["mrp_inr"]),
    ).fetchall()

    alternatives = [
        {
            "name": r["name"],
            "mrp_inr": r["mrp_inr"],
            "is_generic": bool(r["is_generic"]),
            "source": r["source"],
            "pack": r["pack"],
        }
        for r in rows
    ]
    cheapest = alternatives[0] if alternatives else None

    result = {
        "query": name,
        "matched": {
            "name": matched["name"],
            "salt": matched["salt"],
            "strength": matched["strength"],
            "mrp_inr": matched["mrp_inr"],
            "schedule": matched["schedule"],
            "pack": matched["pack"],
        },
        "alternatives": alternatives,
        "cheapest": cheapest,
    }
    if cheapest:
        saved = matched["mrp_inr"] - cheapest["mrp_inr"]
        result["savings_inr"] = round(saved, 2)
        result["savings_pct"] = round(100 * saved / matched["mrp_inr"], 1) if matched["mrp_inr"] else 0.0
    else:
        result["savings_inr"] = 0.0
        result["savings_pct"] = 0.0
    return result

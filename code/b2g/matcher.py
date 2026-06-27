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


FUZZY_THRESHOLD = 0.55          # minimum blended score to accept a fuzzy match

# mass units -> mg factor; ml/iu kept as (value, unit). Lets 1gm == 1000mg == bare 1000.
_MASS_UNITS = {"mg": 1.0, "mcg": 0.001, "g": 1000.0, "gm": 1000.0}
_KEEP_UNITS = {"ml", "iu"}


# units + dosage-form words: not part of the brand identity, excluded from brand scoring
_STOP = frozenset({
    "mg", "mcg", "g", "gm", "ml", "iu",
    "tablet", "tablets", "tab", "tabs", "capsule", "capsules", "cap", "caps",
    "injection", "injections", "inj", "syrup", "cream", "ointment", "oint", "drops",
    "powder", "pow", "gel", "solution", "suspension", "infusion", "spray", "lotion",
    "sr", "er", "xr", "cr", "pr", "od", "dt", "duo", "forte", "plus", "dust", "paste",
})

# Topical/liquid forms where a gram/ml amount in the NAME is the tube/bottle PACK SIZE
# (e.g. "Mupikem Oint 5gm"), not a dose — so it must not be required as a strength.
# (For injections gm/mg IS the dose, so those forms are deliberately excluded here.)
_PACK_SIZE_FORMS = frozenset({
    "ointment", "oint", "cream", "gel", "lotion", "paste",
    "powder", "pow", "dust", "soap", "shampoo",
})


def _is_number(t):
    return bool(t) and t.replace(".", "", 1).isdigit()


def _brand_tokens(tokens):
    """Tokens that identify the brand/molecule — excludes numbers, units, form words."""
    return {t for t in tokens if not _is_number(t) and t not in _STOP}


def _strength_sigs(tokens, drop_pack=False):
    """Unit-aware strength signatures from ordered name tokens -> (mass_mg_set, other_set).

    A number followed by a mass unit (mg/mcg/g/gm) becomes its mg-equivalent; a bare
    number is treated as mg too (tablet strengths); ml/iu keep (value, unit). This makes
    "1 gm" == "1000 mg" == bare "1000" so unit shorthand on receipts matches the catalog.

    drop_pack=True (set for topical/powder queries) ignores gram/ml amounts — on those
    forms the number is a tube/bottle PACK SIZE, not a dose, so it must not be required.
    """
    mass, other = set(), set()
    n, i = len(tokens), 0
    while i < n:
        t = tokens[i]
        if _is_number(t):
            val = float(t)
            nxt = tokens[i + 1] if i + 1 < n else ""
            if nxt in _MASS_UNITS:
                if drop_pack and nxt in ("g", "gm"):    # tube grams on a topical = pack size
                    i += 2; continue
                mass.add(round(val * _MASS_UNITS[nxt], 4)); i += 2; continue
            if nxt in _KEEP_UNITS:
                if drop_pack and nxt == "ml":           # tube/bottle ml = pack size
                    i += 2; continue
                other.add((round(val, 4), nxt)); i += 2; continue
            mass.add(round(val, 4))
        i += 1
    return mass, other


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
    q_letters = {t for t in qtokens if len(t) == 1 and t.isalpha()}
    # On topical/powder queries, a gram/ml amount is the pack size, not a dose -> don't require it.
    q_drop_pack = bool(qtok & _PACK_SIZE_FORMS)
    q_mass, q_other = _strength_sigs(qtokens, drop_pack=q_drop_pack)
    q_brand = _brand_tokens(qtokens)
    best, best_score = None, 0.0
    for r in cands:
        cn = r["name_norm"] or ""
        ctoks = cn.split()
        ctok = set(ctoks)
        # SAFETY: distinguishing tokens must be preserved. Single letters exactly
        # (Vitamin C vs A); numeric strengths are matched UNIT-AWARE (1gm == 1000mg) so
        # we never substitute a different dose — but unit shorthand still lines up.
        if not q_letters.issubset(ctok):
            continue
        c_mass, c_other = _strength_sigs(ctoks)
        if not q_mass.issubset(c_mass) or not q_other.issubset(c_other):
            continue
        # Base on string + token similarity (handles brand≠catalog-name, e.g. Remdac→
        # Remdiz/remdesivir); ADD a brand-token bonus on top so exact-brand matches with
        # format noise (Mepem "1gm inj" vs "1000mg injection") still clear the threshold.
        cbrand = _brand_tokens(ctoks)
        bjacc = len(q_brand & cbrand) / len(q_brand | cbrand) if (q_brand | cbrand) else 0.0
        ratio = difflib.SequenceMatcher(None, norm, cn).ratio()
        jacc = len(qtok & ctok) / len(qtok | ctok) if (qtok | ctok) else 0.0
        score = 0.6 * ratio + 0.4 * jacc + 0.3 * bjacc
        if score > best_score:
            best, best_score = r, score
    return (best, best_score) if best_score >= FUZZY_THRESHOLD else (None, best_score)


def _composition_match(conn, salt, tokens):
    """Given an exact `salt` and the query `tokens`, return the median-priced row of
    that salt whose strength the query satisfies, or None. Shared by the generic
    salt-lookup and the brand-alias lookup."""
    q_mass, q_other = _strength_sigs(tokens, drop_pack=bool(set(tokens) & _PACK_SIZE_FORMS))
    if not (q_mass or q_other):
        return None                                    # need a strength to be safe
    rows = conn.execute(
        "SELECT * FROM drugs WHERE salt = ? AND strength_known = 1 "
        "AND COALESCE(unit_price, mrp_inr) IS NOT NULL LIMIT 2000", (salt,)
    ).fetchall()
    matches = []
    for r in rows:
        sm, so = _strength_sigs(normalize(r["strength"]).split())
        if q_mass.issubset(sm) and q_other.issubset(so):
            matches.append(r)
    if not matches:
        return None
    matches.sort(key=_row_unit_price)
    return matches[len(matches) // 2]                  # median-priced representative


def _salt_lookup(conn, norm):
    """Match a GENERIC name ("Paracetamol 500 mg") by composition, preferring the plain
    single-salt drug over a combo. Returns a representative (median-priced) row or None.

    Without this, a plain generic query prefix-matches a combo product that merely starts
    with the same words (e.g. "Paracetamol 500mg and Caffeine 25mg Tablet").
    """
    tokens = norm.split()
    brand = [t for t in tokens if not _is_number(t) and t not in _STOP]
    if not brand:
        return None
    return _composition_match(conn, " ".join(brand), tokens)  # single-salt only (no '+')


# Very common brands whose exact SKU is missing from the open dataset but whose
# FULL composition is well-covered by generics. Maps brand token -> exact catalog
# salt. PRECISION RULE: only brands whose entire composition exists in the catalog
# (so NOT Saridon — its propyphenazone is absent; aliasing it would be a wrong drug).
_BRAND_ALIASES = {
    "crocin": "paracetamol",
    "dolo": "paracetamol",
    "calpol": "paracetamol",
    "evion": "vitamin e",
    "shelcal": "calcium+vitamin d3",
    "hcqs": "hydroxychloroquine",   # Ipca brand; also covers the OCR garble below
    "hqs": "hydroxychloroquine",    # common Apple-Vision misread of HCQS (no real "HQS" SKU)
}
_GLUED_STRENGTH = re.compile(r"^(\d+(?:\.\d+)?)(mg|mcg|gm|g|ml|iu)$")


def _split_glued(tokens):
    """Split glued strength tokens from real OCR ("650mg" -> "650", "mg")."""
    out = []
    for t in tokens:
        m = _GLUED_STRENGTH.match(t)
        out.extend([m.group(1), m.group(2)] if m else [t])
    return out


def _alias_lookup(conn, norm):
    """Resolve a bare "BRAND <strength>" query for a known brand to its generic salt.

    Fires ONLY when the single non-strength/non-form word is an aliased brand, so a
    variant like "Crocin Cold" (extra descriptor) never aliases to plain paracetamol.
    """
    tokens = _split_glued(norm.split())
    # drop a leading serial number (receipt "S.No" merged into the line, e.g.
    # "27 | CROCIN 650MG") — a real strength comes AFTER the brand, never before.
    while tokens and _is_number(tokens[0]):
        tokens.pop(0)
    # The lone meaningful word must be the alias key. Ignore stray single-char
    # tokens (OCR noise like the "N" in "HQS 300 N").
    words = [t for t in tokens if len(t) >= 2 and not _is_number(t) and t not in _STOP]
    if len(words) != 1:
        return None
    salt = _BRAND_ALIASES.get(words[0])
    if salt is None:
        return None
    return _composition_match(conn, salt, tokens)


def _lookup_drug(conn, name):
    """Find the catalog row for a scanned name. Returns (row, match_type).

    Order: (1) exact normalized, (2) generic salt-name match (plain over combo),
    (3) catalog name is a prefix of the query, (4) query is a prefix of a catalog
    name, (5) conservative fuzzy match. match_type: 'exact'|'generic'|'prefix'|'fuzzy'|None.
    """
    norm = normalize(name)

    row = conn.execute(
        "SELECT * FROM drugs WHERE name_norm = ? ORDER BY mrp_inr LIMIT 1", (norm,)
    ).fetchone()
    if row:
        return row, "exact"

    row = _salt_lookup(conn, norm)
    if row:
        return row, "generic"

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

    row = _alias_lookup(conn, norm)
    if row:
        return row, "alias"

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

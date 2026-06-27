#!/usr/bin/env python3
"""Item-extraction scorer for the OCR benchmark (stdlib only).

We do NOT have char-level ground truth. We DO have a human-verified list of the
drug line-items on each receipt (gold/*.json: name, qty, price). So we score each
engine on how well its raw OCR text recovers those items.

Design (precision-first, OCR-fidelity-isolating):
  * name_recall    — was the drug's *distinctive token* recovered? (e.g. REMDAC,
                     FOLITRAX, HCQS). The single most identifying word, fuzzy-matched.
                     This is the safety-critical signal and the most trustworthy.
  * strength_acc   — for items with a real strength (100MG, 1GM, 100ML, 5GM ...),
                     does the exact strength string appear? A garbled "5OOMG" will
                     NOT match "500MG", so this directly measures OCR fidelity.
  * qty_recall     — qty value present (NOISY: small ints appear everywhere). Reported,
                     lightly weighted.
  * price_recall   — price value present (decimals are fairly distinctive; medium signal).

composite = 0.55*name + 0.30*strength + 0.075*qty + 0.075*price
We weight name+strength to ~85% on purpose: those are what the product depends on.
"""

import json
import re
import unicodedata
from difflib import SequenceMatcher
from pathlib import Path

# Form / unit / packaging words that are NOT a drug's identity.
_STOP = {
    "TAB", "TABS", "TABLET", "TABLETS", "INJ", "INJECTION", "INJECTABLE", "INJECTIONS",
    "OINT", "OINTMENT", "POW", "POWDER", "DUST", "CAP", "CAPS", "CAPSULE", "CAPSULES",
    "STRIP", "DROP", "DROPS", "EYE", "OD", "BD", "TDS", "SR", "XL", "CR", "XR",
    "SYRUP", "SYP", "CREAM", "GEL", "LOTION", "SUSP", "SUSPENSION", "SOLUTION", "SOLN",
    "DRAM", "ML", "MG", "MCG", "GM", "G", "KG", "IU", "K", "UNIT", "UNITS",
    "BTL", "BOTTLE", "PKG", "PKT", "PCS", "NOS", "PC", "VIAL", "AMP", "AMPOULE",
    "DPCO", "MFD", "EXP", "BATCH", "HSN", "QTY", "MRP", "RATE",
}

_STRENGTH_RE = re.compile(r"(\d+(?:\.\d+)?)\s*(MG|MCG|ML|GM|G|IU|K|%)\b", re.IGNORECASE)


def norm(s: str) -> str:
    """Uppercase, drop accents/punctuation (keep digits . % /), collapse whitespace."""
    s = unicodedata.normalize("NFKC", s)
    s = s.upper()
    s = re.sub(r"[^A-Z0-9%./ ]", " ", s)
    s = re.sub(r"\s+", " ", s)
    return s.strip()


def distinctive_token(name: str) -> str:
    """The single most identifying word of a gold item name."""
    toks = [t for t in norm(name).split() if t and not t.isdigit()]
    cand = [t for t in toks if t not in _STOP and not _STRENGTH_RE.fullmatch(t)]
    pool = cand or toks  # fall back to any token if everything was a stopword
    return max(pool, key=len) if pool else ""


def strength_variants(name: str):
    """Return the set of acceptable strength strings for a gold name, or None.

    Only strengths with a unit count (bare numbers like 'HCQS 300' are too noisy).
    Grams accept both G and GM forms ('5GM' ~ '5G')."""
    m = _STRENGTH_RE.search(name)
    if not m:
        return None
    num, unit = m.group(1), m.group(2).upper()
    num = num.rstrip("0").rstrip(".") if "." in num else num  # 500.0 -> 500
    out = set()
    if unit in ("G", "GM"):
        out.add(f"{num}G")
        out.add(f"{num}GM")
    else:
        out.add(f"{num}{unit}")
    return out


def _fuzzy_in(token: str, text_tokens, text_flat: str) -> bool:
    """Is `token` present in the OCR text? Substring or fuzzy word match."""
    if not token:
        return False
    if token in text_flat:  # handles concatenations like REMDAC100MG
        return True
    if len(token) < 4:  # short tokens (NS, B12): exact word only, no fuzz
        return token in text_tokens
    thr = 0.82 if len(token) >= 6 else 0.88
    for w in text_tokens:
        if abs(len(w) - len(token)) > 2:
            continue
        if SequenceMatcher(None, token, w).ratio() >= thr:
            return True
    return False


def _num_variants(value):
    """String forms a numeric value might take in OCR text."""
    if value is None:
        return None
    v = float(value)
    out = {f"{v:.2f}", f"{v:.1f}"}
    if v == int(v):
        out.add(str(int(v)))
    return out


def score_receipt(ocr_text: str, items: list) -> dict:
    """Score one engine's OCR of one receipt against its gold items."""
    text = norm(ocr_text)
    text_tokens = set(text.split())
    text_flat = text.replace(" ", "")

    name_hits = 0
    str_total = str_hits = 0
    qty_total = qty_hits = 0
    price_total = price_hits = 0
    misses = []

    for it in items:
        tok = distinctive_token(it["name"])
        found = _fuzzy_in(tok, text_tokens, text_flat)
        name_hits += 1 if found else 0
        if not found:
            misses.append(it["name"])

        sv = strength_variants(it["name"])
        if sv is not None:
            str_total += 1
            if any(s in text_flat or s in text for s in sv):
                str_hits += 1

        qv = _num_variants(it.get("qty"))
        if qv is not None:
            qty_total += 1
            if any(q in text_tokens for q in qv):
                qty_hits += 1

        pv = _num_variants(it.get("price"))
        if pv is not None:
            price_total += 1
            if any(p in text or p in text_flat for p in pv):
                price_hits += 1

    n = len(items)
    return {
        "n_items": n,
        "name_hits": name_hits,
        "name_recall": name_hits / n if n else 0.0,
        "strength_total": str_total,
        "strength_hits": str_hits,
        "strength_acc": (str_hits / str_total) if str_total else None,
        "qty_total": qty_total,
        "qty_hits": qty_hits,
        "qty_recall": (qty_hits / qty_total) if qty_total else None,
        "price_total": price_total,
        "price_hits": price_hits,
        "price_recall": (price_hits / price_total) if price_total else None,
        "missed_names": misses,
    }


def _safe_ratio(hits, total):
    return (hits / total) if total else None


def aggregate(per_receipt: dict) -> dict:
    """Micro-average across all items of all receipts for one engine."""
    name_h = name_t = 0
    s_h = s_t = 0
    q_h = q_t = 0
    p_h = p_t = 0
    for r in per_receipt.values():
        name_h += r["name_hits"]; name_t += r["n_items"]
        s_h += r["strength_hits"]; s_t += r["strength_total"]
        q_h += r["qty_hits"]; q_t += r["qty_total"]
        p_h += r["price_hits"]; p_t += r["price_total"]

    name = _safe_ratio(name_h, name_t) or 0.0
    strength = _safe_ratio(s_h, s_t) or 0.0
    qty = _safe_ratio(q_h, q_t) or 0.0
    price = _safe_ratio(p_h, p_t) or 0.0
    composite = 0.55 * name + 0.30 * strength + 0.075 * qty + 0.075 * price
    return {
        "name_recall": name,
        "strength_acc": strength,
        "qty_recall": qty,
        "price_recall": price,
        "composite": composite,
        "name_hits": name_h, "name_total": name_t,
        "strength_hits": s_h, "strength_total": s_t,
        "qty_hits": q_h, "qty_total": q_t,
        "price_hits": p_h, "price_total": p_t,
    }


def load_gold(gold_dir: Path) -> dict:
    gold = {}
    for f in sorted(Path(gold_dir).glob("*.json")):
        spec = json.loads(f.read_text(encoding="utf-8"))
        gold[spec["receipt"]] = spec
    return gold


if __name__ == "__main__":
    # quick self-check: perfect transcription should score ~1.0 on name+strength
    gold = load_gold(Path(__file__).parent / "gold")
    for rid, spec in gold.items():
        perfect = "\n".join(f'{it["name"]} {it.get("qty","")} {it.get("price") or ""}'
                            for it in spec["items"])
        r = score_receipt(perfect, spec["items"])
        print(f"{rid}: name {r['name_recall']:.2f}  strength {r['strength_acc']}  "
              f"qty {r['qty_recall']}  price {r['price_recall']}  misses={r['missed_names']}")

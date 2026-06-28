"""Safety Quorum — a multi-agent verification committee over the matcher's output.

Runs ONLY on risky items (non-exact match OR Rx OR narrow-therapeutic-index salt).
Four method-diverse Gemma-4 "lens" agents judge each item in PARALLEL; the verdicts
are merged DETERMINISTICALLY under a one-way ratchet: the quorum can only ADD
caution (lower confidence / add flags / say "verify"), never override the DB.

Stdlib only (calls Cerebras via b2g.cerebras over urllib; threads for fan-out).
"""

import concurrent.futures as futures
import json
import time

from . import cerebras

# --- narrow-therapeutic-index salts: same-drug generic switching needs care ---
# Substring match (DB salts may read "warfarin sodium", "lithium carbonate", ...).
NTI_KEYWORDS = frozenset({
    "warfarin", "acenocoumarol", "levothyroxine", "liothyronine", "phenytoin",
    "carbamazepine", "oxcarbazepine", "valproate", "valproic", "divalproex",
    "lithium", "digoxin", "ciclosporin", "cyclosporine", "tacrolimus", "sirolimus",
    "everolimus", "theophylline", "lamotrigine", "phenobarbital", "phenobarbitone",
    "primidone", "ethosuximide", "procainamide", "quinidine", "flecainide",
    "clozapine", "vancomycin", "gentamicin", "tobramycin", "amikacin",
})


def _norm(s):
    return (s or "").strip().lower()


def is_nti(salt):
    s = _norm(salt)
    return any(k in s for k in NTI_KEYWORDS)


def is_risky(item):
    """Gate: run the committee only where it adds value."""
    if not item.get("found"):
        return False
    m = item["matched"]
    if _norm(m.get("match_type")) != "exact":
        return True
    if item.get("safety", {}).get("requires_rx_confirmation"):
        return True
    return is_nti(m.get("salt"))


# --- the committee ------------------------------------------------------------
LENS_SCHEMA = {
    "type": "object",
    "properties": {
        "verdict": {"type": "string", "enum": ["ok", "caution", "reject"]},
        "confidence": {"type": "integer"},
        "flags": {"type": "array", "items": {"type": "string"}},
        "note": {"type": "string"},
    },
    "required": ["verdict", "confidence", "flags", "note"],
    "additionalProperties": False,
}

_RULE = ("\nReturn ONLY JSON: {\"verdict\":\"ok|caution|reject\",\"confidence\":0-100,"
         "\"flags\":[short tags],\"note\":\"one sentence\"}. You may NOT invent drug "
         "facts; judge only what is given. Be conservative on REAL risks.")

# Prepended to every lens so the committee judges the RIGHT question. The single
# biggest failure mode is penalizing the (expected) brand-name change of a generic.
_CONTEXT = (
    "CONTEXT — how this system works: it helps patients find cheaper GENERIC equivalents. It maps the "
    "scanned brand to its ACTIVE INGREDIENT(S) (salt) + strength + form, then recommends a cheaper "
    "product with the SAME salt + strength + form. The recommended product is DELIBERATELY a DIFFERENT "
    "brand — that is the entire point of generic substitution, so a different brand name is EXPECTED and "
    "is NOT itself a problem. `match_type` shows how the scan was identified: exact/generic = direct; "
    "alias = a curated brand→ingredient mapping (reliable); prefix/fuzzy = a heuristic guess (scrutinize). "
    "Raise a concern ONLY for a real mismatch of ACTIVE INGREDIENT(S), STRENGTH, or ROUTE/FORM, or a "
    "clinical switch-safety issue — NEVER merely because the brand names differ.\n\n"
)

LENSES = [
    ("identity", _CONTEXT +
     "You are the IDENTITY lens. Judge whether the scanned item was correctly identified as the stated "
     "salt + strength + form. For exact/generic/alias, treat the ingredient mapping as reliable unless "
     "the strength or form looks wrong. For prefix/fuzzy, scrutinize whether the scanned text plausibly "
     "means THIS salt at THIS strength and THIS form/route. 'reject' for a clear ingredient/strength/"
     "route error; 'caution' for a shaky guess; 'ok' otherwise. Do NOT penalize brand-name differences." + _RULE),
    ("formulation", _CONTEXT +
     "You are the FORMULATION lens. Flag: (a) a ROUTE/FORM mismatch between the scanned item and the "
     "matched product (e.g. the scan looks like a tablet but the match is an injection); (b) modified-"
     "release (SR/ER/XR) interchange; (c) salt-form interchangeability (e.g. metoprolol succinate vs "
     "tartrate). Otherwise 'ok'." + _RULE),
    ("clinical", _CONTEXT +
     "You are the CLINICAL lens. Is the active ingredient narrow-therapeutic-index (warfarin, "
     "levothyroxine, phenytoin, carbamazepine, lithium, digoxin, tacrolimus, valproate, methotrexate, "
     "etc.) where switching should be doctor-supervised? Use 'caution' (not 'reject') for NTI. Note "
     "prescription-only status if relevant. Do not flag brand-name differences." + _RULE),
    ("skeptic", _CONTEXT +
     "You are the SKEPTIC lens. Argue why the IDENTIFICATION or the SWITCH could be unsafe — focus on "
     "active-ingredient / strength / route mismatches or clinical risks. Credible reason → 'caution' or "
     "'reject'; otherwise 'ok'. Do NOT flag merely because the brand name differs — generics have "
     "different brand names by design." + _RULE),
]

_ORDER = {"ok": 0, "caution": 1, "reject": 2}


def _facts(item):
    m = item["matched"]
    alt = item.get("cheapest_alternative")
    return {
        "ocr_text": item.get("query"),
        "matched_name": m.get("name"),
        "salt": m.get("salt"),
        "strength": m.get("strength"),
        "form": m.get("form"),
        "schedule": m.get("schedule") or "OTC",
        "match_type": m.get("match_type"),
        "switch_to": alt["name"] if alt else None,
    }


def _run_lens(complete, name, system_prompt, user_json):
    messages = cerebras.build_messages(system_prompt, user_json)
    try:
        text, meta = complete(messages, LENS_SCHEMA, name)
        data = cerebras.extract_json(text)
        data["latency_s"] = meta.get("latency_s")
        return data
    except Exception as exc:  # a bad lens must not crash the committee
        return {"verdict": "caution", "confidence": 0, "flags": ["lens_error"],
                "note": f"Lens failed: {exc}", "latency_s": None}


def _safe_score(r):
    """How strongly this lens supports 'safe to switch' (0-100)."""
    v, c = r.get("verdict", "caution"), int(r.get("confidence", 0))
    if v == "ok":
        return c
    if v == "caution":
        return min(c, 55)
    return max(0, (100 - c) // 2)          # a confident 'reject' -> very low


def _merge(item, lens_results):
    m = item["matched"]
    verdicts = [r.get("verdict", "caution") for r in lens_results.values()]
    final = max(verdicts, key=lambda v: _ORDER.get(v, 1))
    overall = min((_safe_score(r) for r in lens_results.values()), default=0)
    flags = sorted({f for r in lens_results.values() for f in r.get("flags", []) if f})
    # Notes from the cautioning/rejecting lenses, most-severe first, deduped and
    # capped (parallel lenses often restate the same concern) for a clean explanation.
    ranked = sorted(
        (r for r in lens_results.values() if r.get("verdict") != "ok" and r.get("note")),
        key=lambda r: _ORDER.get(r.get("verdict"), 1), reverse=True)
    notes = list(dict.fromkeys(r["note"] for r in ranked))[:2]

    base = f"Same {m.get('salt')} {m.get('strength')} {m.get('form') or ''}".strip()
    base += " — equivalent by composition."

    # Infrastructure failure (every lens errored) is NOT a clinical caution — say so.
    if lens_results and all("lens_error" in r.get("flags", []) for r in lens_results.values()):
        return {
            "verdict": "caution", "overall_confidence": 0,
            "label": "Verification unavailable — please retry", "recommend": False,
            "flags": ["verification-unavailable"],
            "explanation": base + " (Quorum could not reach the model; not assessed.)",
            "lenses": lens_results, "verified": True,
        }

    if final == "reject":
        label, recommend = "Couldn't verify — ask a pharmacist", False
    elif final == "caution":
        label, recommend = "Switch with caution", True
    else:
        label, recommend = "Safe to switch", True

    explanation = " ".join([base] + notes) if notes else base

    lat = [r["latency_s"] for r in lens_results.values() if r.get("latency_s")]
    return {
        "verdict": final,
        "overall_confidence": overall,
        "label": label,
        "recommend": recommend,
        "flags": flags,
        "explanation": explanation,
        "lenses": lens_results,
        "verified": True,
    }


def run_item(item, complete):
    user_json = json.dumps(_facts(item))
    t0 = time.monotonic()
    results = {}
    with futures.ThreadPoolExecutor(max_workers=len(LENSES)) as ex:
        fut_to_name = {
            ex.submit(_run_lens, complete, name, prompt, user_json): name
            for name, prompt in LENSES
        }
        for fut in futures.as_completed(fut_to_name):
            results[fut_to_name[fut]] = fut.result()
    wall = time.monotonic() - t0
    merged = _merge(item, results)
    seq = sum(r["latency_s"] for r in results.values() if r.get("latency_s")) or 0.0
    merged["timing"] = {
        "wall_s": round(wall, 3),
        "sequential_s": round(seq, 3),
        "n_calls": len(LENSES),
        "speedup": round(seq / wall, 1) if wall else None,
    }
    return merged


def _auto_pass(item):
    return {
        "verdict": "ok", "overall_confidence": 100, "label": "Safe to switch",
        "recommend": True, "flags": [], "explanation": "Exact OTC match — auto-passed.",
        "verified": False, "auto_pass": True,
    }


def verify_result(result, complete):
    """Attach a `quorum` block to every item; return per-run quorum stats."""
    n_verified = n_flagged = 0
    for item in result.get("items", []):
        if is_risky(item):
            q = run_item(item, complete)
            n_verified += 1
            if q["verdict"] != "ok":
                n_flagged += 1
        else:
            q = _auto_pass(item)
        item["quorum"] = q
    result.setdefault("summary", {}).update(
        {"quorum_verified": n_verified, "quorum_flagged": n_flagged})
    return result


# --- complete() factory: live (Cerebras) or offline mock ----------------------
def make_complete(mock=False):
    """Return complete(messages, schema, tag) -> (text, meta)."""
    if not mock:
        return lambda messages, schema, tag: cerebras.complete(messages, schema=schema)
    return _mock_complete


def _mock_complete(messages, schema, tag):
    """Plausible, rule-based stand-in so the full pipeline runs offline."""
    facts = json.loads(messages[-1]["content"])
    mt = _norm(facts.get("match_type"))
    salt = facts.get("salt")
    rx = _norm(facts.get("schedule")) not in ("", "otc")
    nti = is_nti(salt)

    if tag == "identity":
        if mt in ("exact", "generic"):
            r = {"verdict": "ok", "confidence": 95, "flags": [], "note": "Clear identification."}
        elif mt in ("prefix", "alias"):
            r = {"verdict": "ok", "confidence": 82, "flags": [],
                 "note": f"Matched via {mt}; plausible."}
        elif mt == "fuzzy":
            r = {"verdict": "caution", "confidence": 60, "flags": ["fuzzy-match"],
                 "note": "Name matched fuzzily from OCR text — verify the drug name."}
        else:
            r = {"verdict": "ok", "confidence": 90, "flags": [], "note": "Identified."}
    elif tag == "formulation":
        names = (str(facts.get("matched_name") or "") + " " +
                 str(facts.get("switch_to") or "")).lower().split()
        if any(tok in ("sr", "er", "xr", "cr", "modified") for tok in names):
            r = {"verdict": "caution", "confidence": 65, "flags": ["modified-release"],
                 "note": "A modified-release (SR/ER) form is involved — IR and MR are not "
                         "freely interchangeable; confirm the release type."}
        else:
            r = {"verdict": "ok", "confidence": 90, "flags": [],
                 "note": f"Same {facts.get('form')}; no release/salt-form concern."}
    elif tag == "clinical":
        if nti:
            r = {"verdict": "caution", "confidence": 72, "flags": ["NTI"],
                 "note": f"{salt} is narrow-therapeutic-index — switch under doctor supervision."}
        elif rx:
            r = {"verdict": "ok", "confidence": 88, "flags": ["prescription-only"],
                 "note": "Prescription-only — confirm with your doctor."}
        else:
            r = {"verdict": "ok", "confidence": 95, "flags": [], "note": "No clinical switch concern."}
    else:  # skeptic
        if mt == "fuzzy":
            r = {"verdict": "caution", "confidence": 58, "flags": [],
                 "note": "Low-confidence OCR match; could be a different product."}
        else:
            r = {"verdict": "ok", "confidence": 90, "flags": [], "note": "No red flag found."}
    time.sleep(0.12)   # simulate per-call latency so parallel-vs-sequential timing is realistic
    return json.dumps(r), {"latency_s": 0.12, "usage": None, "time_info": None}

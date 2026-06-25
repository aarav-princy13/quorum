"""Salt + strength canonicalization for the catalog (stdlib only).

Empirical note (2026-06-24): the current open dataset is already internally
consistent on salt spelling — it uses one spelling per drug (paracetamol,
amoxycillin, ...). So the synonym map below is a NEAR-NO-OP on this single
source. It exists for CROSS-SOURCE hygiene: when Jan Aushadhi / NPPA / other
catalogs are merged, they will spell the same active differently. The map sends
those future variants onto the spelling this dataset already uses, so the groups
merge instead of fragmenting. See writeup/DATA_CLEANING.md.

SAFETY POLICY: we canonicalize spelling/synonyms and pharmacopoeia qualifiers
ONLY. We deliberately DO NOT merge different SALT FORMS (e.g. metoprolol
succinate vs tartrate, diclofenac sodium vs potassium) — they are not freely
interchangeable, and collapsing them would produce unsafe substitutions.
"""

import re

# Standards/pharmacopoeia qualifiers safe to drop (same active): "tadalafil ip".
_QUALIFIERS = (
    "ip", "bp", "usp", "jp", "ep", "nf", "ph eur", "pheur",
    "b.p.", "i.p.", "u.s.p.", "b p", "i p",
)

# Curated cross-source synonyms: variant -> canonical (the spelling THIS dataset
# uses, so current rows are unchanged and future sources fold in). Conservative:
# INN/spelling only — NEVER a salt-form collapse.
_SALT_SYNONYMS = {
    "acetaminophen": "paracetamol",
    "albuterol": "salbutamol",
    "amoxicillin": "amoxycillin",
    "cephalexin": "cefalexin",
    "cetrizine": "cetirizine",
    "frusemide": "furosemide",
    "rifampin": "rifampicin",
    "ascorbic acid": "vitamin c",
    "cholecalciferol": "vitamin d3",
    "pyridoxine": "vitamin b6",
}


# PK-NEUTRAL salt forms safe to drop so base ("metformin") and salt
# ("metformin hydrochloride") group together. Deliberately tiny: ONLY forms that
# do not change release/bioavailability. We do NOT strip succinate/tartrate/etc.
# (e.g. metoprolol succinate vs tartrate are NOT interchangeable).
_NEUTRAL_SALT_FORMS = ("hydrochloride", "dihydrochloride", "hcl")


def canonical_salt(salt):
    """Canonicalize one salt name (spelling/synonym/qualifier/PK-neutral-form only)."""
    s = re.sub(r"\s+", " ", (salt or "").strip().lower())
    # drop a trailing pharmacopoeia qualifier word
    for q in _QUALIFIERS:
        if s.endswith(" " + q):
            s = s[: -len(q) - 1].strip()
            break
    # drop a trailing PK-neutral salt form (hydrochloride only — see note above)
    for f in _NEUTRAL_SALT_FORMS:
        if s.endswith(" " + f):
            s = s[: -len(f) - 1].strip()
            break
    return _SALT_SYNONYMS.get(s, s)


def canonical_strength(strength):
    """Normalize a dose string. Returns '' when no real (digit-bearing) dose is present."""
    s = (strength or "").strip().lower().replace(" ", "")
    if not re.search(r"\d", s):          # 'na', '', junk -> unknown dose
        return ""
    s = re.sub(r"(\d)\.0+(?=[a-z%/]|$)", r"\1", s)   # 500.0mg -> 500mg (keep 0.5mg)
    return s

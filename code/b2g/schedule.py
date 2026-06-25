"""Schedule H / H1 / X classification for the safety warning.

Decision (2026-06-24): "warn + confirm Rx" — flag prescription-only / abuse-prone
drugs and require the user to confirm they hold a prescription before we show
purchase / nearby-pharmacy options. This is informational friction, NOT enforcement
(see writeup/MARKET_RESEARCH.md).
"""

# schedule code -> (human label, warning message, requires Rx confirmation?)
_SCHEDULE_INFO = {
    "": (
        "OTC",
        "Over-the-counter. No prescription required.",
        False,
    ),
    "H": (
        "Schedule H (prescription-only)",
        "Prescription-only medicine. Sale without a registered doctor's prescription is not permitted.",
        True,
    ),
    "H1": (
        "Schedule H1 (prescription-only, higher risk)",
        "Prescription-only with higher misuse/overdose risk (e.g. certain antibiotics, "
        "habit-forming drugs). The pharmacy must record the prescription details.",
        True,
    ),
    "X": (
        "Schedule X (narcotic/psychotropic, strict)",
        "Tightly controlled drug. Requires a prescription in duplicate; strictest handling.",
        True,
    ),
}


def classify_schedule(schedule):
    """Return a dict describing the schedule and whether Rx confirmation is needed."""
    code = (schedule or "").strip().upper()
    if code not in _SCHEDULE_INFO:
        code = ""  # unknown codes default to OTC-style (no false alarm), but flag provenance upstream
    label, message, requires_rx = _SCHEDULE_INFO[code]
    return {
        "schedule": code,
        "label": label,
        "message": message,
        "requires_rx_confirmation": requires_rx,
    }


# ---------------------------------------------------------------------------
# Salt -> schedule classification.
#
# The bulk drug dataset has NO schedule column, so we derive it from the active
# salt(s). These sets are a CURATED approximation of India's official Schedule X
# and Schedule H1 lists plus common Schedule H drugs. They MUST be validated
# against the current gazette before production use (see writeup/DATA_SOURCES.md).
# Coverage is intentionally conservative: when unsure we return '' (no false
# "prescription-only" alarm), but H1/X — the overdose/abuse-risk drugs that are
# the core safety concern — are flagged whenever a listed salt appears.
# ---------------------------------------------------------------------------

# Schedule X — narcotic/psychotropic, strictest control (duplicate prescription).
_SALTS_X = frozenset({
    "amphetamine", "dexamphetamine", "methamphetamine", "methylphenidate",
    "amobarbital", "barbital", "pentobarbital", "secobarbital", "methaqualone",
    "glutethimide", "ketamine",
})

# Schedule H1 — prescription-only, higher misuse/overdose risk (record kept).
_SALTS_H1 = frozenset({
    # habit-forming / psychotropic
    "alprazolam", "buprenorphine", "chlordiazepoxide", "clonazepam", "codeine",
    "diazepam", "diphenoxylate", "lorazepam", "midazolam", "nitrazepam",
    "pentazocine", "tramadol", "zolpidem", "zopiclone",
    # anti-TB
    "capreomycin", "cycloserine", "ethambutol", "ethionamide", "isoniazid",
    "pyrazinamide", "rifabutin", "rifampicin",
    # newer antibiotics / cephalosporins / carbapenems / fluoroquinolones
    "cefdinir", "cefditoren", "cefepime", "cefetamet", "cefixime", "cefoperazone",
    "cefotaxime", "cefpirome", "cefpodoxime", "ceftazidime", "ceftibuten",
    "ceftizoxime", "ceftriaxone", "cefuroxime", "doripenem", "ertapenem",
    "faropenem", "imipenem", "meropenem", "sulbactam", "tigecycline",
    "balofloxacin", "gemifloxacin", "moxifloxacin", "prulifloxacin", "sparfloxacin",
})

# Schedule H — common prescription-only drugs (non-exhaustive curated set).
_SALTS_H = frozenset({
    "amoxycillin", "amoxicillin", "ampicillin", "azithromycin", "cefalexin",
    "cephalexin", "clarithromycin", "clindamycin", "ciprofloxacin", "ofloxacin",
    "levofloxacin", "norfloxacin", "doxycycline", "metronidazole", "ornidazole",
    "fluconazole", "itraconazole", "acyclovir", "metformin", "glimepiride",
    "gliclazide", "sitagliptin", "telmisartan", "losartan", "olmesartan",
    "amlodipine", "ramipril", "enalapril", "atenolol", "metoprolol",
    "atorvastatin", "rosuvastatin", "clopidogrel", "pantoprazole", "omeprazole",
    "rabeprazole", "esomeprazole", "ondansetron", "montelukast", "prednisolone",
    "dexamethasone", "methylprednisolone", "levothyroxine", "warfarin",
    "aceclofenac", "etoricoxib", "gabapentin", "pregabalin", "sertraline",
    "escitalopram", "fluoxetine", "amitriptyline", "olanzapine", "risperidone",
    "levetiracetam", "valproate", "carbamazepine", "salbutamol", "budesonide",
    "tamsulosin", "finasteride", "sildenafil", "tadalafil",
    # antivirals (prescription-only; several are restricted hospital drugs)
    "remdesivir", "favipiravir", "molnupiravir", "oseltamivir", "valacyclovir",
    "ganciclovir", "ritonavir", "lopinavir", "tenofovir", "dolutegravir",
    # injectable antibiotics / anti-infectives (Schedule H)
    "piperacillin", "tazobactam", "vancomycin", "teicoplanin", "colistin",
    "linezolid", "amikacin", "gentamicin", "ceftriaxone", "metronidazole",
    # cytotoxic / oncology (prescription-only, cytotoxic)
    "doxorubicin", "cisplatin", "carboplatin", "oxaliplatin", "paclitaxel",
    "docetaxel", "cyclophosphamide", "methotrexate", "gemcitabine", "fluorouracil",
    "vincristine", "vinblastine", "imatinib", "rituximab", "trastuzumab",
    # anticoagulants / other parenterals commonly billed
    "enoxaparin", "heparin", "dalteparin", "filgrastim",
})

# Dosage forms that are essentially never sold over the counter — used as a
# safety fallback so an unrecognised injectable is still flagged prescription-only.
_RX_FORMS = frozenset({"injection", "infusion"})


def schedule_for_salts(salt_text):
    """Map a (possibly combined) salt string to the strictest applicable schedule.

    `salt_text` may be a single salt or a '+'-joined combination, e.g.
    "amoxycillin+clavulanic acid". Returns '' | 'H' | 'H1' | 'X'.
    """
    components = [c.strip().lower() for c in (salt_text or "").split("+") if c.strip()]
    best = ""
    rank = {"": 0, "H": 1, "H1": 2, "X": 3}
    for comp in components:
        code = ""
        if any(s in comp for s in _SALTS_X):
            code = "X"
        elif any(s in comp for s in _SALTS_H1):
            code = "H1"
        elif any(s in comp for s in _SALTS_H):
            code = "H"
        if rank[code] > rank[best]:
            best = code
    return best


def schedule_for(salt_text, form=""):
    """Schedule from salt, with a parenteral-form fallback.

    If the salt isn't in our curated lists but the dosage form is an injection/
    infusion, default to 'H' (prescription-only) — injectables are not sold OTC, so
    erring toward a warning is the safe choice for the 'can they buy it' feature.
    """
    code = schedule_for_salts(salt_text)
    if code:
        return code
    if (form or "").strip().lower() in _RX_FORMS:
        return "H"
    return ""

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

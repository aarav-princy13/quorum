"""Small shared parsing helpers (stdlib only)."""

import re

# Count + unit, e.g. "strip of 10 tablets", "bottle of 100 ml Syrup", "vial of 1 Injection".
_UNIT_RE = re.compile(
    r"(\d+)\s*(tablets?|capsules?|ml|injections?|drops?|sachets?|pieces?|gm|g\b)",
    re.IGNORECASE,
)


def parse_pack_units(pack):
    """Estimate the number of comparable units in a pack (tablets, ml, ...).

    Used to normalize pack prices to a per-unit basis so a "strip of 10" isn't
    compared naively against a single tablet. Falls back to 1 when unknown.
    """
    pack = pack or ""
    matches = _UNIT_RE.findall(pack)
    if matches:
        return int(matches[-1][0])          # count adjacent to the dosage unit
    m = re.search(r"\d+", pack)
    return int(m.group()) if m else 1

"""Small shared parsing helpers (stdlib only)."""

import math
import re


def haversine_km(lat1, lon1, lat2, lon2):
    """Great-circle distance in km between two lat/lon points (stdlib math)."""
    r = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lon2 - lon1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))

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

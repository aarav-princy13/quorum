"""Orchestration: parsed receipt line items -> per-item generic/savings/safety results.

The receipt image is OCR'd ON-DEVICE (out of scope here); this backend receives only
TEXT line items, e.g. [{"name": "Crocin 500", "qty": 1}, ...]. That keeps the photo
on the phone (privacy decision, 2026-06-24).
"""

from .matcher import find_alternatives
from .schedule import classify_schedule


def process_receipt(conn, line_items):
    """Process a list of {"name": str, "qty": int?} items.

    Returns {"items": [...], "summary": {...}}.
    """
    items = []
    total_savings = 0.0
    flagged = 0

    for li in line_items:
        name = li.get("name", "")
        raw_qty = li.get("qty")                       # None = receipt had no usable qty

        alt = find_alternatives(conn, name)
        schedule_code = alt["matched"]["schedule"] if alt["matched"] else ""
        safety = classify_schedule(schedule_code)

        # Savings scale with the number of UNITS (tablets/ml) bought, priced at the
        # per-unit gap — never per pack, which would multiply by pack size and
        # overstate. When the receipt gives no qty, fall back to one pack worth
        # (the realistic minimum purchase), so we estimate without overstating.
        per_unit = alt.get("savings_per_unit", 0.0)
        pack_units = int(alt["matched"]["units"] or 1) if alt["matched"] else 1
        qty = raw_qty if isinstance(raw_qty, int) else pack_units
        line_savings = round(per_unit * qty, 2)
        savings_pack = alt.get("savings_pack", 0.0)
        total_savings += line_savings
        if safety["requires_rx_confirmation"]:
            flagged += 1

        items.append({
            "query": name,
            "qty": qty,
            "found": alt["matched"] is not None,
            "matched": alt["matched"],
            "cheapest_alternative": alt["cheapest"],
            "cheapest_authoritative": alt.get("cheapest_authoritative"),
            "alternatives": alt["alternatives"],
            "n_alternatives": alt.get("n_alternatives", 0),
            "savings_inr_per_unit": alt.get("savings_per_unit", 0.0),
            "savings_inr_pack": savings_pack,
            "savings_inr_line": line_savings,
            "savings_pct": alt.get("savings_pct", 0.0),
            "safety": safety,
        })

    summary = {
        "n_items": len(items),
        "n_found": sum(1 for it in items if it["found"]),
        "n_rx_flagged": flagged,
        "total_savings_inr": round(total_savings, 2),
    }
    return {"items": items, "summary": summary}


def nearby_pharmacies(conn, lat=None, lon=None, limit=8, kinds=None, max_km=None):
    """Locations-only nearby lookup (no live inventory).

    Neutral: returns any nearby pharmacy. When lat/lon are given, ranks by real
    great-circle distance (km) and returns the closest `limit`; Jan Aushadhi
    Kendras are tagged so the caller can highlight them. `max_km`, when set,
    drops anything farther than that radius so a far-away catalogue row is never
    presented as "nearby".
    """
    from .util import haversine_km

    sql = "SELECT * FROM pharmacies"
    params = []
    if kinds:
        sql += f" WHERE kind IN ({','.join('?' for _ in kinds)})"
        params.extend(kinds)
    rows = [dict(r) for r in conn.execute(sql, params).fetchall()]

    if lat is not None and lon is not None:
        for r in rows:
            r["distance_km"] = (round(haversine_km(lat, lon, r["lat"], r["lon"]), 2)
                                if r["lat"] is not None and r["lon"] is not None else None)
        rows = [r for r in rows if r["distance_km"] is not None]
        if max_km is not None:
            rows = [r for r in rows if r["distance_km"] <= max_km]
        rows.sort(key=lambda r: r["distance_km"])
    return rows[:limit]

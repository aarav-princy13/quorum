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
        qty = int(li.get("qty", 1) or 1)

        alt = find_alternatives(conn, name)
        schedule_code = alt["matched"]["schedule"] if alt["matched"] else ""
        safety = classify_schedule(schedule_code)

        per_unit_savings = alt.get("savings_inr", 0.0)
        line_savings = round(per_unit_savings * qty, 2)
        total_savings += line_savings
        if safety["requires_rx_confirmation"]:
            flagged += 1

        items.append({
            "query": name,
            "qty": qty,
            "found": alt["matched"] is not None,
            "matched": alt["matched"],
            "cheapest_alternative": alt["cheapest"],
            "alternatives": alt["alternatives"],
            "savings_inr_per_unit": per_unit_savings,
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


def nearby_pharmacies(conn, city=None, kinds=("jan_aushadhi", "generic")):
    """Locations-only nearby lookup for the MVP (no live inventory).

    Filters by city and pharmacy kind. Real geo-distance ranking comes later.
    """
    sql = "SELECT * FROM pharmacies"
    clauses, params = [], []
    if city:
        clauses.append("city = ?")
        params.append(city)
    if kinds:
        clauses.append(f"kind IN ({','.join('?' for _ in kinds)})")
        params.extend(kinds)
    if clauses:
        sql += " WHERE " + " AND ".join(clauses)
    return [dict(r) for r in conn.execute(sql, params).fetchall()]

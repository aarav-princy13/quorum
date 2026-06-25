"""Human-readable text rendering of a pipeline result (shared by demo.py / query.py)."""


def rupees(x):
    if x is None:
        return "₹—"
    return f"₹{x:,.2f}"


def build_report(result, pharmacies=None, title="receipt analysis"):
    """Render a pipeline result dict (from pipeline.process_receipt) as text."""
    lines = []
    lines.append("=" * 64)
    lines.append(f"  brand_to_generic — {title}")
    lines.append("=" * 64)

    for it in result["items"]:
        lines.append("")
        if not it["found"]:
            lines.append(f"• {it['query']}  (x{it['qty']})  —  not found in catalog")
            continue
        m = it["matched"]
        approx = f"   ≈ approx match: {m['name']}" if m.get("match_type") == "fuzzy" else ""
        lines.append(f"• {it['query']}  (x{it['qty']}){approx}")
        lines.append(
            f"    composition : {m['salt']} {m['strength']} ({m['form'] or 'n/a'})  "
            f"[{m['pack']}]  MRP {rupees(m['mrp_inr'])} = {rupees(m['unit_price'])}/unit"
        )
        safety = it["safety"]
        if safety["requires_rx_confirmation"]:
            lines.append(f"    ⚠ {safety['label']} — {safety['message']}")
            lines.append("      action: confirm you hold a valid prescription before buying.")
        cheap = it["cheapest_alternative"]
        if cheap:
            tag = "generic" if cheap["is_generic"] else "cheaper option"
            if cheap.get("is_authoritative"):
                tag += " ✓Jan Aushadhi (govt)"
            n_alt = it.get("n_alternatives", 0)
            more = f"  (+{n_alt - 1} other cheaper option(s))" if n_alt > 1 else ""
            lines.append(
                f"    → {tag}: {cheap['name']}  [{cheap['pack']}]  "
                f"{rupees(cheap['unit_price'])}/unit  "
                f"(save {rupees(it['savings_inr_per_unit'])}/unit, {it['savings_pct']}%){more}"
            )
            lines.append(
                f"      savings to buy the same quantity (x{it['qty']}): {rupees(it['savings_inr_line'])}"
            )
            # If the cheapest isn't itself official, surface the official price as a trusted anchor.
            auth = it.get("cheapest_authoritative")
            if auth and not cheap.get("is_authoritative"):
                lines.append(
                    f"      ✓ official Jan Aushadhi price: {rupees(auth['unit_price'])}/unit"
                    f"  ({auth['name']})"
                )
        else:
            lines.append("    → no cheaper same-form equivalent found")

    s = result["summary"]
    lines.append("")
    lines.append("-" * 64)
    lines.append(
        f"  {s['n_found']}/{s['n_items']} items matched · "
        f"{s['n_rx_flagged']} need Rx confirmation · "
        f"TOTAL POTENTIAL SAVINGS: {rupees(s['total_savings_inr'])}"
    )
    lines.append("-" * 64)

    if pharmacies:
        lines.append("")
        lines.append("  Nearest pharmacies (locations-only MVP; ✓ = Jan Aushadhi Kendra):")
        for p in pharmacies:
            dist = f"{p['distance_km']:>5} km" if p.get("distance_km") is not None else "       "
            mark = " ✓" if p.get("kind") == "jan_aushadhi" else "  "
            where = p.get("area") or p.get("city") or ""
            tail = f"  ({where})" if where else ""
            lines.append(f"    {dist} {mark} {p['name']}{tail}")

    lines.append("")
    lines.append("  Note: suggestions are informational. Confirm substitutions with a")
    lines.append("  pharmacist or doctor before switching.")
    return "\n".join(lines)

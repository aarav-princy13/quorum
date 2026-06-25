#!/usr/bin/env python3
"""Runnable demo of the brand_to_generic backend (stdlib only).

Simulates what the Flutter app will send AFTER on-device OCR: a list of text
line items from a pharmacy receipt. Runs the pipeline (generic match + savings +
Schedule H/H1/X safety), prints a readable report, and writes artifacts to output/.

Run from the repo root:  python3 code/demo.py
"""

import json
import sys
from pathlib import Path

# Make the b2g package importable when run as a script.
CODE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(CODE_DIR))
OUTPUT_DIR = CODE_DIR.parent / "output"

from b2g.db import connect, build_db, load_seed              # noqa: E402
from b2g.pipeline import process_receipt, nearby_pharmacies  # noqa: E402

# A stand-in for an OCR'd Chandigarh pharmacy receipt (names as they'd be printed).
SAMPLE_RECEIPT = [
    {"name": "Crocin 500", "qty": 2},
    {"name": "Augmentin 625 Duo", "qty": 1},   # antibiotic -> Schedule H1 warning
    {"name": "Pan 40", "qty": 1},
    {"name": "Alprax 0.5", "qty": 1},          # alprazolam -> H1, overdose-risk warning
    {"name": "Vitamin C Chewable", "qty": 1},  # not in catalog -> shows "not found" path
]


def rupees(x):
    return f"₹{x:,.2f}"


def build_report(result, pharmacies):
    """Render a human-readable text report from the pipeline result."""
    lines = []
    lines.append("=" * 64)
    lines.append("  brand_to_generic — receipt analysis (DEMO / illustrative prices)")
    lines.append("=" * 64)

    for it in result["items"]:
        lines.append("")
        if not it["found"]:
            lines.append(f"• {it['query']}  (x{it['qty']})  —  not found in catalog yet")
            continue
        m = it["matched"]
        lines.append(f"• {it['query']}  (x{it['qty']})")
        lines.append(f"    composition : {m['salt']} {m['strength']}  [{m['pack']}]  MRP {rupees(m['mrp_inr'])}")
        safety = it["safety"]
        if safety["requires_rx_confirmation"]:
            lines.append(f"    ⚠ {safety['label']} — {safety['message']}")
            lines.append(f"      action: confirm you hold a valid prescription before buying.")
        cheap = it["cheapest_alternative"]
        if cheap:
            tag = "generic" if cheap["is_generic"] else "cheaper brand"
            lines.append(
                f"    → {tag}: {cheap['name']} @ {rupees(cheap['mrp_inr'])}  "
                f"(save {rupees(it['savings_inr_per_unit'])}/unit, {it['savings_pct']}%)"
            )
            lines.append(f"      line savings (x{it['qty']}): {rupees(it['savings_inr_line'])}")
        else:
            lines.append("    → no cheaper equivalent found")

    s = result["summary"]
    lines.append("")
    lines.append("-" * 64)
    lines.append(
        f"  {s['n_found']}/{s['n_items']} items matched · "
        f"{s['n_rx_flagged']} need Rx confirmation · "
        f"TOTAL POTENTIAL SAVINGS: {rupees(s['total_savings_inr'])}"
    )
    lines.append("-" * 64)

    lines.append("")
    lines.append("  Nearby generic-friendly pharmacies (locations-only MVP):")
    for p in pharmacies:
        lines.append(f"    - {p['name']} [{p['kind']}], {p['area']}, {p['city']}")

    lines.append("")
    lines.append("  Note: suggestions are informational. Confirm substitutions with a")
    lines.append("  pharmacist or doctor. Prices here are illustrative seed data.")
    return "\n".join(lines)


def main():
    conn = connect()             # in-memory DB for the demo
    build_db(conn)
    n_drugs, n_ph = load_seed(conn)

    result = process_receipt(conn, SAMPLE_RECEIPT)
    pharmacies = nearby_pharmacies(conn, city="Chandigarh")
    report = build_report(result, pharmacies)
    print(report)

    OUTPUT_DIR.mkdir(exist_ok=True)
    (OUTPUT_DIR / "demo_result.json").write_text(
        json.dumps({"result": result, "pharmacies": pharmacies}, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    (OUTPUT_DIR / "demo_report.txt").write_text(report, encoding="utf-8")
    print(f"\n[loaded {n_drugs} drugs, {n_ph} pharmacies]")
    print(f"[wrote {OUTPUT_DIR / 'demo_result.json'} and demo_report.txt]")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Run the pipeline over OCR'd receipt fixtures and report how it does on real receipts.

The fixtures in code/ocr_samples/*.json are line items extracted from real (internet-
sourced) pharmacy receipts by a vision model — i.e. the VLM-OCR path. This exercises
the full pipeline on messy real-world names and surfaces matching gaps.

  python3 code/ocr_bench.py        (needs data/b2g.db; build with ingest scripts)

NOTE: this measures the *pipeline* (match -> savings -> safety) on VLM-extracted text.
A true on-device OCR *engine* comparison (ML Kit vs Granite-Docling latency/accuracy)
needs the mobile harness and is out of scope here.
"""

import json
import sqlite3
import sys
from pathlib import Path

CODE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(CODE_DIR))
ROOT = CODE_DIR.parent
DB_PATH = ROOT / "data" / "b2g.db"
SAMPLES = CODE_DIR / "ocr_samples"
OUT = ROOT / "output" / "ocr"

from b2g.pipeline import process_receipt   # noqa: E402


def rupees(x):
    return "—" if x is None else f"₹{x:,.2f}"


def main():
    if not DB_PATH.exists():
        sys.exit(f"DB not found: {DB_PATH} (run code/ingest.py first)")
    conn = sqlite3.connect(f"file:{DB_PATH}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row

    OUT.mkdir(parents=True, exist_ok=True)
    fixtures = sorted(SAMPLES.glob("*.json"))
    grand = {"items": 0, "matched": 0, "fuzzy": 0, "rx": 0, "savings": 0.0}
    report = []

    for fx in fixtures:
        spec = json.loads(fx.read_text(encoding="utf-8"))
        res = process_receipt(conn, spec["items"])
        report.append(f"\n=== {spec['receipt']} ({spec['format']}) — {spec['vendor']} ===")
        report.append(f"    {spec.get('note','')}")
        for it in res["items"]:
            grand["items"] += 1
            if not it["found"]:
                report.append(f"    ✗ {it['query']!r}  → not found")
                continue
            grand["matched"] += 1
            m = it["matched"]
            if m.get("match_type") == "fuzzy":
                grand["fuzzy"] += 1
            if it["safety"]["requires_rx_confirmation"]:
                grand["rx"] += 1
            grand["savings"] += it["savings_inr_line"]
            ch = it["cheapest_alternative"]
            tag = (" ✓JanAushadhi" if (ch and ch.get("is_authoritative"))
                   else "") if ch else ""
            sched = it["safety"]["schedule"] or "OTC"
            approx = " (≈fuzzy)" if m.get("match_type") == "fuzzy" else ""
            cheap = (f"cheapest {rupees(ch['unit_price'])}/u{tag}, save {it['savings_pct']}%"
                     if ch else "no cheaper option")
            report.append(f"    ✓ {it['query']!r}{approx}  → {m['salt']} {m['strength']} "
                          f"[{sched}] · {cheap}")

    report.append("\n" + "=" * 60)
    report.append(f"  items {grand['items']} · matched {grand['matched']} "
                  f"({grand['fuzzy']} fuzzy) · not found {grand['items']-grand['matched']} "
                  f"· Rx-flagged {grand['rx']}")
    report.append(f"  total potential savings across receipts: {rupees(round(grand['savings'],2))}")
    report.append("=" * 60)

    text = "\n".join(report)
    print(text)
    (OUT / "ocr_bench_report.txt").write_text(text, encoding="utf-8")
    print(f"\n[wrote {OUT/'ocr_bench_report.txt'}]")
    conn.close()


if __name__ == "__main__":
    main()

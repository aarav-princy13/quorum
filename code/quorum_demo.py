#!/usr/bin/env python3
"""Demo: receipt line items -> matcher -> Safety Quorum -> report.

  python3 code/quorum_demo.py                       # auto: live if CEREBRAS_API_KEY else mock
  python3 code/quorum_demo.py --mock                # force offline mock
  python3 code/quorum_demo.py "HCQS 300 Tablet" "Warfarin 5 mg Tablet"

The receipt image OCR is out of scope here (text in). The quorum runs ONLY on
risky items (non-exact match / Rx / NTI); exact OTC matches auto-pass.
"""

import argparse
import json
import sqlite3
import sys
from pathlib import Path

CODE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(CODE_DIR))
DB_PATH = CODE_DIR.parent / "data" / "b2g.db"
OUTPUT_DIR = CODE_DIR.parent / "output"

from b2g import cerebras, quorum                       # noqa: E402
from b2g.pipeline import process_receipt               # noqa: E402

SAMPLE = [
    "HCQS 300 Tablet",        # hydroxychloroquine, Rx (Schedule H), non-exact
    "Warfarin 5 mg Tablet",   # NTI -> doctor-supervised switch
    "Pan 40 Tablet",          # pantoprazole, Rx
    "Glycomet 500 Tablet",    # metformin
    "Telma 40 Tablet",        # telmisartan
]


def _fmt_money(x):
    return f"₹{x:.2f}" if x else "₹0"


def report(result, live):
    out = []
    mode = "LIVE (gemma-4-31b on Cerebras)" if live else "MOCK (offline)"
    out.append(f"Safety Quorum demo — {mode}")
    out.append("=" * 68)
    for it in result["items"]:
        q = it.get("quorum", {})
        if not it["found"]:
            out.append(f"\n• {it['query']}  →  not found (no recommendation)")
            continue
        m = it["matched"]
        alt = it.get("cheapest_alternative")
        out.append(f"\n• {it['query']}")
        out.append(f"    matched : {m['name']}  [{m['salt']} {m['strength']} {m['form']}, "
                   f"{m['match_type']}, {it['safety']['label']}]")
        if alt:
            out.append(f"    cheaper : {alt['name']}  {_fmt_money(alt['unit_price'])}/unit  "
                       f"(save {it['savings_pct']}% , {_fmt_money(it['savings_inr_line'])}/line)")
        tag = "AUTO-PASS" if q.get("auto_pass") else "VERIFIED"
        out.append(f"    quorum  : [{tag}] {q.get('label')}  "
                   f"(conf {q.get('overall_confidence')}%, verdict {q.get('verdict')})")
        if q.get("flags"):
            out.append(f"              flags: {', '.join(q['flags'])}")
        out.append(f"              {q.get('explanation')}")
        if q.get("timing"):
            t = q["timing"]
            out.append(f"              {t['n_calls']} agents: {t['wall_s']}s parallel vs "
                       f"{t['sequential_s']}s sequential ({t['speedup']}x)")
    s = result["summary"]
    out.append("\n" + "-" * 68)
    out.append(f"items {s['n_items']} | found {s['n_found']} | Rx-flagged {s['n_rx_flagged']} | "
               f"quorum verified {s.get('quorum_verified', 0)}, flagged {s.get('quorum_flagged', 0)}")
    out.append(f"total savings: {_fmt_money(s['total_savings_inr'])}")
    return "\n".join(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("names", nargs="*", help="receipt line items (default: sample)")
    ap.add_argument("--mock", action="store_true", help="force offline mock")
    ap.add_argument("--live", action="store_true", help="force live API")
    args = ap.parse_args()

    if not DB_PATH.exists():
        sys.exit(f"DB not found: {DB_PATH}\nBuild it first (see code/README.md).")

    live = args.live or (cerebras.have_key() and not args.mock)
    names = args.names or SAMPLE
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    result = process_receipt(conn, [{"name": n, "qty": 1} for n in names])
    quorum.verify_result(result, quorum.make_complete(mock=not live))
    conn.close()

    text = report(result, live)
    print(text)
    OUTPUT_DIR.mkdir(exist_ok=True)
    (OUTPUT_DIR / "quorum_result.json").write_text(
        json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
    (OUTPUT_DIR / "quorum_report.txt").write_text(text, encoding="utf-8")


if __name__ == "__main__":
    main()

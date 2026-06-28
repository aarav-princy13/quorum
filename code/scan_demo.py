#!/usr/bin/env python3
"""End-to-end demo: receipt IMAGE -> Gemma-4 vision OCR -> matcher -> Safety Quorum.

  python3 code/scan_demo.py                 # default receipt pharm_5, auto live/mock
  python3 code/scan_demo.py pharm_1         # a bundled sample receipt
  python3 code/scan_demo.py path/to/bill.jpg
  python3 code/scan_demo.py --mock          # offline: use the human-verified fixtures

Live uses the OPT-IN Cerebras VLM OCR path (image -> Gemma 4). Mock uses the gold
ocr_samples fixtures so the full pipeline runs offline.
"""

import argparse
import sqlite3
import sys
from pathlib import Path

CODE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(CODE_DIR))
ROOT = CODE_DIR.parent
DB_PATH = ROOT / "data" / "b2g.db"

from b2g import cerebras, quorum, vlm_ocr               # noqa: E402
from b2g.matcher import normalize                       # noqa: E402
from b2g.pipeline import process_receipt                # noqa: E402
from quorum_demo import report                          # noqa: E402


def _resolve(arg):
    """Return (receipt_id_or_None, image_path_or_None) from a sample id or a path."""
    if arg:
        p = Path(arg)
        if p.exists():
            return (p.stem if p.stem.startswith("pharm_") else None), p
        hits = sorted(ROOT.glob(f"{arg}.*"))             # e.g. "pharm_5" -> pharm_5.jpeg
        if hits:
            return arg, hits[0]
        sys.exit(f"Receipt not found: {arg}")
    hits = sorted(ROOT.glob("pharm_5.*"))
    return "pharm_5", (hits[0] if hits else None)


def _ocr_accuracy(got, gold):
    """How many gold items the OCR recovered (normalized brand+strength match)."""
    def keys(items):
        return [normalize(it["name"]) for it in items]
    gk, gotk = keys(gold), set(keys(got))
    hit = sum(1 for k in gk if any(k in g or g in k for g in gotk))
    return hit, len(gk)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("receipt", nargs="?", help="sample id (pharm_5) or image path")
    ap.add_argument("--mock", action="store_true")
    ap.add_argument("--live", action="store_true")
    args = ap.parse_args()

    if not DB_PATH.exists():
        sys.exit(f"DB not found: {DB_PATH} (see code/README.md).")

    live = args.live or (cerebras.have_key() and not args.mock)
    receipt_id, image_path = _resolve(args.receipt)
    gold = vlm_ocr.gold_items(receipt_id) if receipt_id else None

    print("Receipt → Gemma-4 vision OCR → matcher → Safety Quorum")
    print("=" * 68)
    if live:
        if not image_path:
            sys.exit("No image to OCR (live mode needs an image file).")
        print(f"OCR (LIVE, gemma-4-31b vision): {image_path.name}")
        items, meta = vlm_ocr.ocr_receipt(image_path)
        if meta:
            print(f"  read {len(items)} line items in {meta.get('latency_s')}s")
        if gold:
            hit, total = _ocr_accuracy(items, gold)
            print(f"  vs human-verified gold: {hit}/{total} items recovered")
    else:
        if not gold:
            sys.exit("Mock mode needs a bundled sample (e.g. pharm_5).")
        items = gold
        print(f"OCR (MOCK, gold fixture): {receipt_id} — {len(items)} line items")
    for it in items:
        print(f"    - {it['name']} (x{it.get('qty', 1)})")

    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    result = process_receipt(conn, [{"name": it["name"], "qty": it.get("qty", 1)} for it in items])
    quorum.verify_result(result, quorum.make_complete(mock=not live))
    conn.close()

    print()
    print(report(result, live))


if __name__ == "__main__":
    main()

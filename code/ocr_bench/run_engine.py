#!/usr/bin/env python3
"""Run ONE engine over a set of images, in an isolated subprocess.

Isolation matters: each engine (especially a multi-GB VLM) loads its model in its
own process, so peak RAM is measured cleanly and memory is released between engines.
Emits a JSON result file. Invoked by bench.py; not usually run by hand."""

import argparse
import json
import platform
import resource
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from engines import get_engine  # noqa: E402


def peak_rss_mb():
    self_rss = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
    child_rss = resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss
    raw = max(self_rss, child_rss)
    # macOS getrusage reports bytes; Linux reports kilobytes.
    return raw / (1024 * 1024) if platform.system() == "Darwin" else raw / 1024


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--engine", required=True)
    ap.add_argument("--images", nargs="+", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    result = {"engine": args.engine}
    out_path = Path(args.out)

    try:
        eng = get_engine(args.engine)
    except Exception as e:  # adapter module missing / import-time failure
        result.update({"available": False, "reason": f"adapter not loadable: {e}"})
        out_path.write_text(json.dumps(result))
        return

    try:
        ok, reason = eng.available()
    except Exception as e:
        ok, reason = False, f"available() raised: {e}"
    result["available"] = ok
    result["reason"] = reason
    result["heavy"] = getattr(eng, "heavy", False)
    if not ok:
        out_path.write_text(json.dumps(result))
        return

    try:
        rows = eng.ocr_batch(args.images)
    except Exception as e:
        result.update({"error": f"ocr_batch failed: {e}"})
        out_path.write_text(json.dumps(result))
        return

    result["per_image"] = [
        {"image": img, "seconds": r.get("seconds", -1.0),
         "text": r.get("text", ""), "chars": len(r.get("text", ""))}
        for img, r in zip(args.images, rows)
    ]
    result["peak_rss_mb"] = round(peak_rss_mb(), 1)
    out_path.write_text(json.dumps(result))


if __name__ == "__main__":
    main()

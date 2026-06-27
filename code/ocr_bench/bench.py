#!/usr/bin/env python3
"""OCR engine benchmark orchestrator (stdlib only).

Runs each OCR engine (in its own subprocess) over the receipt images, scores the
output against the human-verified gold line-items, and writes a ranked report.

  python3 code/ocr_bench/bench.py                  # all available engines, all receipts
  python3 code/ocr_bench/bench.py --engines apple_vision tesseract
  python3 code/ocr_bench/bench.py --venv code/ocr_bench/.venv/bin/python   # enable VLMs

Privacy: 100% local. pharm_5 is a REAL patient bill — no engine here uploads images.
Engines whose deps aren't installed are auto-skipped (reported, not fatal).
"""

import argparse
import json
import statistics
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

BENCH_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BENCH_DIR))
import score as scorer  # noqa: E402
from engines import all_names, get_engine  # noqa: E402

REPO_ROOT = BENCH_DIR.parent.parent
DEFAULT_OUT = REPO_ROOT / "output" / "ocr_bench"


def find_images():
    return sorted(p for p in REPO_ROOT.glob("pharm_*")
                  if p.suffix.lower() in {".webp", ".jpg", ".jpeg", ".png", ".heic"})


def to_png(src: Path, cache: Path, max_dim: int) -> Path:
    """Normalise every input to PNG (uniform format; webp-safe) via macOS sips,
    bounding the long edge to max_dim so huge photos don't dominate runtime."""
    dst = cache / (src.stem + ".png")
    if dst.exists() and dst.stat().st_mtime >= src.stat().st_mtime:
        return dst
    cmd = ["sips", "-s", "format", "png"]
    if max_dim and max_dim > 0:
        cmd += ["-Z", str(max_dim)]
    cmd += [str(src), "--out", str(dst)]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        raise RuntimeError(f"sips failed on {src.name}: {proc.stderr.strip()}")
    return dst


def engine_meta(name):
    """(heavy, requires_venv, load_error) without triggering heavy imports."""
    try:
        eng = get_engine(name)
        return getattr(eng, "heavy", False), getattr(eng, "requires_venv", False), None
    except Exception as e:
        return False, False, str(e)


def run_one(name, images, interp, out_dir):
    """Spawn run_engine.py for one engine; return its parsed result dict."""
    res_path = out_dir / f"_result_{name}.json"
    cmd = [interp, str(BENCH_DIR / "run_engine.py"),
           "--engine", name, "--out", str(res_path),
           "--images", *map(str, images)]
    t0 = time.perf_counter()
    proc = subprocess.run(cmd, capture_output=True, text=True)
    wall = time.perf_counter() - t0
    if res_path.exists():
        data = json.loads(res_path.read_text())
    else:
        data = {"engine": name, "available": False,
                "reason": f"subprocess produced no result (rc={proc.returncode}): "
                          f"{proc.stderr.strip()[:300]}"}
    data["wall_seconds"] = round(wall, 2)
    return data


def median_secs(per_image):
    vals = [r["seconds"] for r in per_image if r.get("seconds", -1) >= 0]
    return round(statistics.median(vals), 2) if vals else None


def fmt_pct(x):
    return "—" if x is None else f"{x * 100:.0f}%"


def build_report(results, gold, images, args):
    """results: list of engine dicts (with per_image + scores attached)."""
    ran = [r for r in results if r.get("scored")]
    skipped = [r for r in results if not r.get("scored")]
    ran.sort(key=lambda r: r["agg"]["composite"], reverse=True)

    lines = []
    lines.append("# OCR engine benchmark")
    lines.append("")
    lines.append(f"_Generated: {args.stamp}_  ·  receipts: {len(images)}  ·  "
                 f"max image dim: {args.max_dim or 'native'}px")
    lines.append("")
    lines.append("Scored on **drug line-item extraction** vs human-verified gold "
                 "(`code/ocr_bench/gold/`). Composite = 0.55·name + 0.30·strength + "
                 "0.075·qty + 0.075·price. Name + strength are the trustworthy, "
                 "safety-critical signals; qty/price are presence-based and noisier.")
    lines.append("")
    lines.append("| # | Engine | Composite | Name | Strength | Qty | Price | Med s/img | Peak RAM |")
    lines.append("|---|--------|-----------|------|----------|-----|-------|-----------|----------|")
    for i, r in enumerate(ran, 1):
        a = r["agg"]
        ram = f'{r.get("peak_rss_mb", 0):.0f} MB' if r.get("peak_rss_mb") else "—"
        lines.append(
            f"| {i} | {r['engine']} | **{a['composite'] * 100:.0f}** | "
            f"{fmt_pct(a['name_recall'])} | {fmt_pct(a['strength_acc'])} | "
            f"{fmt_pct(a['qty_recall'])} | {fmt_pct(a['price_recall'])} | "
            f"{median_secs(r['per_image']) or '—'} | {ram} |")
    lines.append("")

    # Per-receipt name recall (where the real differences show)
    lines.append("## Name recall per receipt")
    lines.append("")
    header = "| Engine | " + " | ".join(g for g in sorted(gold)) + " |"
    lines.append(header)
    lines.append("|" + "---|" * (len(gold) + 1))
    for r in ran:
        cells = []
        for rid in sorted(gold):
            pr = r["per_receipt"].get(rid)
            cells.append(fmt_pct(pr["name_recall"]) if pr else "—")
        lines.append(f"| {r['engine']} | " + " | ".join(cells) + " |")
    lines.append("")

    # Safety view: which drugs each engine MISSED entirely.
    lines.append("## Missed drugs (name not recovered)")
    lines.append("")
    any_miss = False
    for r in ran:
        misses = []
        for rid in sorted(gold):
            pr = r["per_receipt"].get(rid)
            if pr and pr["missed_names"]:
                misses += [f"{m} ({rid})" for m in pr["missed_names"]]
        if misses:
            any_miss = True
            lines.append(f"- **{r['engine']}**: {', '.join(misses)}")
    if not any_miss:
        lines.append("_None — every engine recovered every gold drug name._")
    lines.append("")

    if skipped:
        lines.append("## Skipped / not available")
        lines.append("")
        for r in skipped:
            lines.append(f"- **{r['engine']}**: {r.get('reason') or r.get('error')}")
        lines.append("")

    lines.append("## Notes")
    lines.append("- Apple Vision = on-device macOS, proxy for the iOS lightweight tier; "
                 "first image folds in model-load time.")
    lines.append("- Latency/RAM here are **Mac dev-box** figures — indicative for ranking, "
                 "not on-phone numbers. Lightweight engines (ML Kit, Paddle-Lite) are "
                 "validated on-device later in the app phase.")
    lines.append("- gold prices are partial/noisy (some receipts illegible); treat the "
                 "price column as a weak signal.")
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--engines", nargs="+", default=None,
                    help="engine names (default: all registered)")
    ap.add_argument("--images", nargs="+", default=None,
                    help="image paths (default: pharm_* at repo root)")
    ap.add_argument("--venv", default=None,
                    help="python interpreter for VLM (requires_venv) engines")
    ap.add_argument("--jobs", type=int, default=2,
                    help="max light engines to run in parallel (heavy run serially)")
    ap.add_argument("--max-dim", type=int, default=3000,
                    help="bound image long edge in px (0 = native)")
    ap.add_argument("--out", default=str(DEFAULT_OUT))
    ap.add_argument("--keep-text", action="store_true",
                    help="dump each engine's raw OCR text under <out>/raw/")
    ap.add_argument("--report-only", action="store_true",
                    help="rebuild the combined report from cached _result_*.json (no re-run)")
    args = ap.parse_args()
    args.stamp = time.strftime("%Y-%m-%d %H:%M")

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    cache = out_dir / "_img"
    cache.mkdir(exist_ok=True)

    gold = scorer.load_gold(BENCH_DIR / "gold")
    results = []

    if args.report_only:
        # Rebuild the combined report from every cached _result_*.json — no re-run.
        for rf in sorted(out_dir.glob("_result_*.json")):
            results.append(json.loads(rf.read_text()))
        images = sorted(cache.glob("*.png"))
        if not results:
            sys.exit(f"--report-only: no cached _result_*.json in {out_dir}")
        print(f"report-only: {len(results)} cached engine results")
    else:
        srcs = [Path(p) for p in args.images] if args.images else find_images()
        if not srcs:
            sys.exit("no receipt images found (expected pharm_* at repo root)")
        images = [to_png(s, cache, args.max_dim) for s in srcs]
        print(f"images: {', '.join(p.name for p in images)}")

        names = args.engines or all_names()
        light, heavy = [], []
        for n in names:
            is_heavy, needs_venv, load_err = engine_meta(n)
            interp = args.venv if (needs_venv and args.venv) else sys.executable
            (heavy if is_heavy else light).append((n, interp, needs_venv, load_err))

        def dispatch(item):
            n, interp, needs_venv, load_err = item
            if needs_venv and not args.venv:
                return {"engine": n, "available": False,
                        "reason": "needs VLM venv (pass --venv ...); skipped"}
            if load_err:
                return {"engine": n, "available": False,
                        "reason": f"adapter not loadable: {load_err}"}
            print(f"  running {n} ...")
            return run_one(n, images, interp, out_dir)

        # light engines in parallel
        if light:
            with ThreadPoolExecutor(max_workers=max(1, args.jobs)) as ex:
                futs = {ex.submit(dispatch, it): it[0] for it in light}
                for f in as_completed(futs):
                    results.append(f.result())
        # heavy engines one at a time (RAM)
        for it in heavy:
            results.append(dispatch(it))

    # score
    for r in results:
        if not r.get("available") or "per_image" not in r:
            r["scored"] = False
            continue
        per_receipt = {}
        for pi in r["per_image"]:
            rid = Path(pi["image"]).stem
            if rid in gold:
                per_receipt[rid] = scorer.score_receipt(pi["text"], gold[rid]["items"])
        r["per_receipt"] = per_receipt
        r["agg"] = scorer.aggregate(per_receipt)
        r["scored"] = bool(per_receipt)
        if args.keep_text:
            raw = out_dir / "raw" / r["engine"]
            raw.mkdir(parents=True, exist_ok=True)
            for pi in r["per_image"]:
                (raw / f"{Path(pi['image']).stem}.txt").write_text(pi["text"])

    report = build_report(results, gold, images, args)
    (out_dir / "report.md").write_text(report)
    (out_dir / "results.json").write_text(json.dumps(results, indent=2, default=str))
    print("\n" + report)
    print(f"\nwrote {out_dir / 'report.md'}")


if __name__ == "__main__":
    main()

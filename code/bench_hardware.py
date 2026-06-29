#!/usr/bin/env python3
"""Hardware speed comparison for the demo: Cerebras vs a local Mac model.

Runs the SAME prompt, SAME settings, through the SAME code path against:
  • Cerebras  — gemma-4-31b  (wafer-scale inference)         CEREBRAS_API_KEY
  • Local Mac — qwen4boQ4 via an OpenAI-compatible server    OMLX_API_KEY

Both are OpenAI-compatible chat-completions endpoints, so the request is
identical — only the hardware differs. Reports end-to-end latency and
tokens/sec (median of N runs) + the speedup, and writes output/hardware_compare.json.

  python3 code/bench_hardware.py                 # 3 runs each
  python3 code/bench_hardware.py --runs 5
  python3 code/bench_hardware.py --local-model qwen4boQ4 --local-url http://localhost:8000/v1

Prereqs: `export CEREBRAS_API_KEY=…`, `export OMLX_API_KEY=…`, and your local
server serving the model on :8000. Stdlib only.
"""

import argparse
import json
import os
import statistics
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

OUTPUT_DIR = Path(__file__).resolve().parent.parent / "output"

SYSTEM = "You are a clinical pharmacist."
USER = (
    "A patient's bill lists 'HCQS 300' (hydroxychloroquine 300 mg tablet, "
    "prescription-only). Is it safe to substitute it with a cheaper generic that "
    "has the same salt, strength, and form? Explain in 3-4 sentences and note any "
    "safety caveats."
)
MAX_TOKENS = 256
UA = "brand-to-generic-quorum/1.0"   # Cerebras (Cloudflare) blocks the default urllib UA


def _post(base_url, api_key, model, timeout=120):
    """One chat completion. Returns (completion_tokens, wall_seconds)."""
    body = json.dumps({
        "model": model,
        "messages": [{"role": "system", "content": SYSTEM},
                     {"role": "user", "content": USER}],
        "max_tokens": MAX_TOKENS,
        "temperature": 0,
        "stream": False,
    }).encode("utf-8")
    req = urllib.request.Request(
        base_url.rstrip("/") + "/chat/completions", data=body, method="POST",
        headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json",
                 "Accept": "application/json", "User-Agent": UA})
    t0 = time.monotonic()
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        data = json.load(resp)
    wall = time.monotonic() - t0
    usage = data.get("usage") or {}
    return usage.get("completion_tokens"), wall


def _bench(label, base_url, api_key, model, runs):
    print(f"\n• {label}: {model}  ({base_url})")
    try:
        _post(base_url, api_key, model)            # warm-up (loads weights), untimed
    except urllib.error.URLError as exc:
        print(f"    SKIP — could not reach endpoint: {exc}")
        return None
    walls, toks = [], []
    for i in range(runs):
        tk, wall = _post(base_url, api_key, model)
        walls.append(wall)
        if tk:
            toks.append(tk)
        print(f"    run {i + 1}: {wall:.2f}s" + (f", {tk} tok" if tk else ""))
    med_wall = statistics.median(walls)
    med_tok = statistics.median(toks) if toks else None
    tps = (med_tok / med_wall) if med_tok else None
    return {"label": label, "model": model, "wall_s": round(med_wall, 3),
            "completion_tokens": med_tok,
            "tokens_per_s": round(tps, 1) if tps else None}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs", type=int, default=3)
    ap.add_argument("--local-url", default="http://localhost:8000/v1")
    ap.add_argument("--local-model", default="qwen4boQ4")
    ap.add_argument("--cerebras-model", default="gemma-4-31b")
    args = ap.parse_args()

    cere_key = os.environ.get("CEREBRAS_API_KEY")
    omlx_key = os.environ.get("OMLX_API_KEY", "not-needed")
    if not cere_key:
        sys.exit("Set CEREBRAS_API_KEY first.")

    print("Hardware speed comparison — same prompt, same settings")
    cerebras = _bench("Cerebras (wafer-scale)", "https://api.cerebras.ai/v1",
                      cere_key, args.cerebras_model, args.runs)
    local = _bench("Mac (Apple Silicon)", args.local_url, omlx_key,
                   args.local_model, args.runs)

    print("\n" + "=" * 60)
    rows = [r for r in (cerebras, local) if r]
    for r in rows:
        tps = f"{r['tokens_per_s']} tok/s" if r["tokens_per_s"] else "tok/s n/a"
        print(f"  {r['label']:<24} {r['wall_s']:>7.2f}s   {tps}")
    if cerebras and local:
        print("-" * 60)
        print(f"  → Cerebras is {local['wall_s'] / cerebras['wall_s']:.1f}x faster end-to-end"
              + (f", {local['tokens_per_s'] and cerebras['tokens_per_s'] and round(cerebras['tokens_per_s'] / local['tokens_per_s'], 1)}x throughput"
                 if (cerebras['tokens_per_s'] and local['tokens_per_s']) else ""))

    OUTPUT_DIR.mkdir(exist_ok=True)
    (OUTPUT_DIR / "hardware_compare.json").write_text(
        json.dumps({"cerebras": cerebras, "local": local}, indent=2), encoding="utf-8")
    print(f"\nsaved {OUTPUT_DIR / 'hardware_compare.json'}")


if __name__ == "__main__":
    main()

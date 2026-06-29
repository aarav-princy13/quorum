#!/usr/bin/env python3
"""Inference speed comparison for the demo — same model family, different hardware.

Runs the SAME prompt, SAME settings, through the SAME OpenAI-compatible code path
against whichever providers you have configured:
  • Cerebras       — gemma-4-31b on wafer-scale            CEREBRAS_API_KEY   (required)
  • Google AI Studio — Gemma on Google GPU/TPU             GOOGLE_API_KEY     (if set)
  • Local Mac      — a local model via OpenAI-compat server OMLX_API_KEY      (if reachable)

The headline comparison is Cerebras-Gemma vs Google-Gemma: same family, comparable
size, both cloud — so the gap reflects the INFERENCE HARDWARE, not the model.
(AI Studio serves Gemma 3; Gemma 4 31B is the Cerebras preview model.)

  python3 code/bench_hardware.py                       # all configured providers, 3 runs
  python3 code/bench_hardware.py --runs 5 --no-local
  python3 code/bench_hardware.py --google-model gemma-4-31B

Prereqs: export the keys above; for local, serve the model on :8000. Stdlib only.
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
    except Exception as exc:                        # unreachable / bad model id -> skip
        detail = exc.read().decode("utf-8", "replace")[:160] if hasattr(exc, "read") else exc
        print(f"    SKIP — {detail}")
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
            "completion_tokens": med_tok, "tokens_per_s": round(tps, 1) if tps else None}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs", type=int, default=3)
    ap.add_argument("--cerebras-model", default="gemma-4-31b")
    ap.add_argument("--google-model", default="gemma-4-31b-it")
    ap.add_argument("--local-url", default="http://localhost:8000/v1")
    ap.add_argument("--local-model", default="QwenPaw-Flash-4B-oQ4-fp16")
    ap.add_argument("--no-local", action="store_true", help="skip the local Mac model")
    args = ap.parse_args()

    cere_key = os.environ.get("CEREBRAS_API_KEY")
    if not cere_key:
        sys.exit("Set CEREBRAS_API_KEY first.")
    google_key = os.environ.get("GOOGLE_API_KEY") or os.environ.get("GEMINI_API_KEY")

    contenders = [("Cerebras · Gemma 4 (wafer-scale)", "https://api.cerebras.ai/v1",
                   cere_key, args.cerebras_model)]
    if google_key:
        contenders.append(("Google AI Studio · Gemma 4 (GPU/TPU)",
                           "https://generativelanguage.googleapis.com/v1beta/openai",
                           google_key, args.google_model))
    else:
        print("(no GOOGLE_API_KEY / GEMINI_API_KEY — skipping Google AI Studio)")
    if not args.no_local:
        contenders.append(("Local Mac (Apple Silicon)", args.local_url,
                           os.environ.get("OMLX_API_KEY", "not-needed"), args.local_model))

    print("Inference speed — same prompt, same settings, different hardware")
    results = [r for r in (_bench(*c, args.runs) for c in contenders) if r]

    print("\n" + "=" * 64)
    for r in results:
        tps = f"{r['tokens_per_s']} tok/s" if r["tokens_per_s"] else "tok/s n/a"
        print(f"  {r['label']:<38} {r['wall_s']:>6.2f}s   {tps:>12}")
    cere = results[0] if results and results[0]["label"].startswith("Cerebras") else None
    if cere:
        print("-" * 64)
        for r in results[1:]:
            faster = r["wall_s"] / cere["wall_s"]
            thru = (cere["tokens_per_s"] / r["tokens_per_s"]
                    if (cere["tokens_per_s"] and r["tokens_per_s"]) else None)
            line = f"  → vs {r['label']}: {faster:.1f}x faster end-to-end"
            if thru:
                line += f", {thru:.1f}x throughput"
            print(line)
    print("\n  note: tok/s = end-to-end throughput (incl. network); models may stop at\n"
          "  different lengths, so tok/s is the fairest hardware metric.")

    OUTPUT_DIR.mkdir(exist_ok=True)
    (OUTPUT_DIR / "hardware_compare.json").write_text(
        json.dumps({"results": results}, indent=2), encoding="utf-8")
    print(f"\nsaved {OUTPUT_DIR / 'hardware_compare.json'}")


if __name__ == "__main__":
    main()

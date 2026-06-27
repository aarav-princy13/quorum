# OCR engine benchmark

Picks the on-device OCR engine for the app **with evidence**, not vibes. Runs each
candidate over real Indian pharmacy receipts and scores it on **drug line-item
extraction** — the thing the product actually depends on.

## Why item-extraction (not CER/WER)
We have no char-level ground truth, and for this product raw character accuracy is
the wrong target. What matters is: *did we recover the drug, its strength, and price
correctly?* A wrong drug is worse than a miss (precision-first). So we score against a
human-verified list of each receipt's line-items (`gold/*.json`).

```
composite = 0.55·name_recall + 0.30·strength_acc + 0.075·qty_recall + 0.075·price_recall
```
- **name_recall** — was the drug's *distinctive token* recovered (REMDAC, FOLITRAX, HCQS)?
  Fuzzy-matched. Safety-critical and most trustworthy. A garbled name (EVION→"ION")
  correctly scores as a miss — you can't safely identify the drug.
- **strength_acc** — does the exact strength string appear (100MG, 1GM, 5GM)? A garbled
  `5OOMG` won't match `500MG`, so this directly measures OCR fidelity.
- **qty/price** — presence-based, noisier (small ints/decimals). Reported, lightly weighted.

## Privacy
100% local. `pharm_5` is a REAL patient bill — **no engine here uploads images.** No
cloud OCR is included by design.

## Engines & device tiers
The app tiers OCR by phone RAM. The benchmark validates the accuracy ceiling + the VLM
tier on the Mac; the truly-lightweight mobile SDKs (ML Kit, Paddle-Lite) are validated
on-device later in the app phase.

| Engine | Tier | Stage | Install |
|--------|------|-------|---------|
| `apple_vision` | ≤4GB (iOS lightweight proxy) | 1 ✅ | none (Swift + macOS) |
| `tesseract` | CPU baseline | 1 ✅ | `brew install tesseract` |
| `paddleocr` (PP-OCRv5) | ≤4GB (deployable via Paddle-Lite) | 2 | venv: `paddleocr` |
| `paddleocr_vl` / `got_ocr2` | ~6GB middle (0.9B / 580M VLM) | 3 | venv: torch/transformers |
| `unlimited_ocr` / `deepseek_ocr` / `dots_ocr` / `mineru` / `moondream` | 8GB+ heavy VLM | 3 | venv: torch/transformers, multi-GB weights |

Engines whose deps aren't installed are **auto-skipped** (reported, never fatal).

## Run
```bash
python3 code/ocr_bench/bench.py                         # all available engines, all receipts
python3 code/ocr_bench/bench.py --engines apple_vision tesseract --keep-text
python3 code/ocr_bench/bench.py --venv code/ocr_bench/.venv/bin/python   # enable VLMs (Stage 3)
```
Output → `output/ocr_bench/report.md` (ranked table + per-receipt name recall + missed-drug
safety view) and `results.json`. `--keep-text` dumps each engine's raw OCR under `raw/`.

Flags: `--jobs N` (light engines in parallel; heavy VLMs always serial for RAM),
`--max-dim PX` (bound image long edge, default 3000), `--images ...`, `--engines ...`.

## Gold (`gold/*.json`)
Decoupled from `code/ocr_samples/` (the pipeline benchmark) on purpose — corrected here
after eyeballing each image:
- pharm_1: NS 100ML qty 2→3 (Total 113.16 = 37.72×3).
- pharm_4: filled prices from image (140 / 74 / 984).
- pharm_5: PREGEB & FLEXON prices nulled (source values didn't match the image).
- pharm_3: low-res watermarked *sample* template — weak test image, prices null.

(The same corrections are worth applying to `code/ocr_samples/` for the pipeline benchmark.)

## Adding an engine
Add a module in `engines/` whose class subclasses `Engine` and implements
`available() -> (ok, reason)` and `ocr_batch(paths) -> [{"text","seconds"}]`. Do heavy
imports *inside* methods (keeps the registry cheap; missing deps degrade to skip).
Register it in `engines/__init__.py`. Set `heavy=True` for big-RAM VLMs and
`requires_venv=True` to run it under the VLM venv.

## Caveats
- Latency/RAM are **Mac dev-box** figures — for ranking, not on-phone numbers.
- Apple Vision's first image folds in model-load time.
- gold prices are partial/noisy; treat the price column as a weak signal.

# Architecture & Tech Feasibility

**Date:** 2026-06-24 · Inputs: cross-platform (iOS+Android), on-device image processing for privacy, Tesseract rejected, backend-pipeline OK, locations-only data, warn+confirm-Rx.

> Model facts below are from web research current to mid-2026 (see Sources). On-device receipt accuracy is **unproven for our case** and must be benchmarked on real Indian pharmacy receipts before committing.

## 1. The privacy constraint shapes everything
Owner wants the **receipt image processed on-device** (never uploaded). That's compatible with also having a **stateless backend** — as long as only *extracted text / drug names* leave the device, not the photo. This split satisfies both stated wants.

```
┌─────────────── On device (mobile app) ───────────────┐      ┌──── Backend (stateless API, no UI) ────┐
│ Camera → receipt image                                │      │ Python, stdlib-first, no pandas        │
│   → On-device OCR / VLM  → structured line items      │ ───▶ │ • brand→generic mapping (drug DB)      │
│   (image NEVER leaves the device)                     │ text │ • Schedule H/H1/X classify + warn      │
│ Show savings, warnings, nearby pharmacies             │ ◀─── │ • savings calc                         │
└───────────────────────────────────────────────────────┘ JSON │ • nearby-pharmacy lookup (maps+govt)   │
                                                                └────────────────────────────────────────┘
```
Only non-image text crosses the network. (Even drug names are health-sensitive — see open question on the privacy boundary.)

## 2. On-device OCR options (2026 landscape)
Two tiers; we likely combine them.

**A. Native on-device text OCR — recommended baseline**
- **Google ML Kit Text Recognition v2** — cross-platform (Android + iOS), free, fast, on-device, TFLite-based. **Supports Devanagari** (Hindi) — relevant for India. Gives text + bounding boxes; *we* parse into line items.
- **Apple Vision framework** — excellent, but **iOS only** (kills single-codebase reuse).
- Verdict: ML Kit is the cross-platform baseline. Far stronger than Tesseract on real-world lighting/fonts.

**B. On-device small VLM — for structure / messy receipts**
Turns image (or OCR text) directly into structured JSON line items in one pass. 2026 small models that can run on-device:
- **IBM Granite-Docling-258M** (Jan 2026, Apache-2.0) — purpose-built document understanding (tables/forms), runs locally on Apple Silicon via MLX; mobile-phone deployment is plausible but unproven.
- **SmolVLM-256M** (<1 GB memory), **MiniCPM-V (~3B, runs on phones)**, **MagicVL-2B** (designed for mobile), **Phi-4-multimodal**, **Pixtral** (lightweight).
- Trade-off: better structure handling vs. larger app size, battery/thermal, and accuracy that must be tested.

**C. Cloud VLMs** (dots.ocr 1.7B, Qwen3-VL, GLM-4.5V, DeepSeek-VL2, Nemotron-3-Nano-Omni) — highest accuracy, but **violate the on-device/privacy goal**. Reserve only as an *opt-in* fallback, if at all.

**Recommended OCR path:** prototype with ML Kit text + rule/regex parsing; in parallel benchmark **Granite-Docling-258M** and one small VLM on real receipts. Pick the lightest engine that clears an accuracy bar. Decide empirically, not from spec sheets.

## 3. Cross-platform app framework
| Option | iOS+Android one codebase | On-device ML access | Notes |
|--------|--------------------------|---------------------|-------|
| **Flutter** | ✅ | ML Kit plugin, good camera | Clean single codebase; strong for this use case |
| **React Native** | ✅ | ML Kit community libs | Fine if JS/TS preferred |
| **Native (Swift+Kotlin)** | ❌ (2 codebases) | Best (Apple Vision + ML Kit) | Most effort; best raw capability |
- Leaning **Flutter** for one codebase + solid ML Kit/camera support. Open for confirmation.

## 4. Backend (the "python pipeline")
- Python, **stdlib-first, no pandas**. Likely a tiny HTTP API (`http.server` or one lightweight framework if justified) + **SQLite** for the drug/price DB.
- Responsibilities: brand→generic mapping, Schedule H/H1/X classification + warning, savings calc, nearby-pharmacy lookup.
- Doubles as the **Phase-1 desktop prototype**: run the whole flow on sample receipt images (using a local VLM on the dev machine) to validate logic *before* building the mobile app.

## 5. Data sources (locations-only MVP)
- **brand→generic mapping & MRP:** public **NPPA** price data, **Jan Aushadhi / PMBJP** product list, CDSCO. Assemble into local SQLite. (No pandas — use `csv`/`sqlite3`.)
- **nearby pharmacies:** maps provider (Google Places / OpenStreetMap) for locations; Jan Aushadhi Kendra directory for generic-friendly stores. **No live inventory in MVP.**
- **Schedule H/H1/X list:** compile the official schedules into a lookup table.

## 6. Recommended phased build
1. **Phase 1 — Desktop Python prototype:** drug DB (SQLite) + brand→generic + schedule classify + savings, driven by a local VLM OCR on sample receipts. Proves the core.
2. **Phase 2 — Cross-platform app:** Flutter shell, on-device OCR (ML Kit/VLM), calls the backend for mapping/lookup. Image stays on device.
3. **Phase 3 — Pilot + (later) pharmacy partnerships for live inventory.**

## 7. Decisions (resolved 2026-06-24)
- App framework: **Flutter** (eventual app) — but **build the Python backend first**.
- Privacy boundary: **image stays on-device; only extracted text reaches the backend.**
- On-device OCR engine: **decide by benchmark** on real receipts (ML Kit vs Granite-Docling vs small VLM).
- Drug/price data: **assemble open composition dataset + Jan Aushadhi + NPPA into SQLite** (see DATA_SOURCES.md); verify licensing before commercial.

Backend scaffold built under `code/` (runnable `demo.py`); see code/README.md.

## Sources
- https://www.ibm.com/new/announcements/granite-docling-end-to-end-document-conversion — Granite-Docling-258M (Jan 2026)
- https://huggingface.co/ibm-granite/granite-docling-258M
- https://github.com/docling-project/docling
- https://instavar.com/blog/ai-production-stack/OCR_SOTA_Feb_2026_Open_Document_AI_Leaderboard — OCRBench v2 (2026.03)
- https://www.bentoml.com/blog/multimodal-ai-a-guide-to-open-source-vision-language-models
- https://v-chandra.github.io/on-device-llms/ — On-Device LLMs: State of the Union 2026
- https://arxiv.org/pdf/2508.01540 — MagicVL-2B (mobile VLM)
- https://developers.google.com/ml-kit/vision/text-recognition/v2/android — ML Kit Text Recognition v2 (Devanagari support)
- https://www.bitfactory.io/de/dev-blog/comparing-on-device-ocr-frameworks-apple-vision-and-google-mlkit/
- https://www.designveloper.com/blog/mobile-ocr-libraries/

# Session transfer — brand_to_generic

**Updated:** 2026-06-27 · Single entry point for continuing this project in a new session.
Read this first, then the docs it links. Owner: **Aarav**.

---

## 1. What this is
An India-focused app: **scan a pharmacy receipt → OCR on-device → flag prescription-only /
abuse-prone drugs (Schedule H/H1/X) → find cheaper *generic* equivalents + official Jan Aushadhi
prices + nearby pharmacies.** Goal: help cost-conscious patients pay less for the same medicine, safely.

## 2. Current state (one line)
**Full vertical slice works end-to-end on a real receipt on an iPhone:** capture → on-device Apple
Vision OCR → parse → signed `/v1/analyze` → real Results (savings + Rx/Schedule flags + nearby).
Backend + the pharm_5 safety/coverage gaps are fixed. Remaining = more screens, polish, productionization (§9).

## 3. Hard constraints / owner preferences (don't violate)
- **Python backend: standard library only. NO pandas / heavy deps.** (Exception, approved: the OCR
  *benchmark* `code/ocr_bench/` uses heavy ML libs, isolated in its own gitignored venv — not the app path.)
- **Privacy:** the receipt *image* is OCR'd on-device and never uploaded — only extracted text is sent.
- **Precision over recall:** a wrong drug is worse than a miss. Never guess a composition we can't back
  (e.g. Saridon stays "not found" — see §7).
- **Git:** author `Aarav <aarav10a1@gmail.com>`, **NO `Co-Authored-By` trailer**. Commit when work lands.
- Owner values: methodical, evidence-first (measure before assuming), honest about limitations, asks-don't-assume.

## 4. Repo layout
```
code/            Python backend (stdlib). b2g/ package + scripts.
code/app/        Flutter app (iOS+Android). NEW this session.
code/ocr_bench/  OCR-engine benchmark harness + gold + venv (heavy deps, isolated). NEW this session.
output/          generated artifacts (gitignored bulk)
writeup/         SPEC, MARKET_RESEARCH, ARCHITECTURE, DATA_SOURCES, DATA_CLEANING, API_DESIGN,
                 BENCHMARK, DESIGN, TODO, SESSION
data/            (gitignored) raw downloads + built SQLite b2g.db
secrets/         (gitignored) dev API key (keys.json) + self-signed TLS cert
```
`pharm_*` receipt images (incl. the real pharm_5) and `data/` + `secrets/` are gitignored.
⚠️ **Most of this session's work is UNCOMMITTED** — review `git status` and commit (author convention §12).

## 5. Backend (`code/`) — built + updated this session
- **Catalog DB** `data/b2g.db` (gitignored; rebuild in §11): open Indian Medicine Dataset (~248k rows
  in table `drugs`) + **official Jan Aushadhi prices** (`is_authoritative=1`). `pharmacies` table (OSM).
- **Package `code/b2g/`:** `db`, `normalize`, `schedule`, `matcher` (the brains), `pipeline`, `report`,
  `util`, `security` (HMAC + rate limit).
- **Matching** (`matcher.py`), precision-first: exact → salt-lookup → prefix → **brand-alias** → fuzzy.
  Guards: unit-aware strengths (1gm=1000mg), pack-size-aware, discriminator guard, median outlier floor.
- **Secure HTTPS API** (`server.py`): TLS, API key + HMAC(SHA256) with per-request nonce, rate-limit,
  strict caps, **rejects chunked bodies** (client must send Content-Length), read-only DB.
  `client_example.py` is the signed-request blueprint (ported to Dart, §6). Routes: `POST /v1/analyze`,
  **`POST /v1/nearby`** (`{location}`→`{pharmacies}`; backs address search), `GET /v1/health`. Nearby
  ranks within `NEARBY_MAX_KM`=50 (`nearby_pharmacies(..., max_km=)` in `pipeline.py`).

### Backend changes this session
1. **Schedule safety fix (DMARDs):** added DMARD/immunosuppressant/biologic salts (hydroxychloroquine,
   leflunomide, sulfasalazine, azathioprine, mycophenolate, tacrolimus, tofacitinib, adalimumab, …) to
   `_SALTS_H` in `b2g/schedule.py`. Re-derive the `schedule` column WITHOUT a re-ingest:
   **`python3 code/recompute_schedule.py`** (NEW; idempotent; 1039 rows reclassified OTC→H). HCQS/LEFRA now flag Rx.
2. **Brand→salt aliases** in `matcher.py` `_BRAND_ALIASES` for common brands whose SKU is absent but whose
   FULL composition exists: `crocin/dolo/calpol→paracetamol`, `evion→vitamin e`, `shelcal→calcium+vitamin d3`,
   `hcqs/hqs→hydroxychloroquine`. Gated to bare "BRAND+strength" (so "Crocin Cold" never aliases), tolerant
   of a leading S.No and stray single-char OCR tokens, splits glued strengths ("650mg"→"650","mg").
3. `code/test_matching.py` extended (Crocin650 / Evion400 / Shelcal500 / HQS-garble wins + a Saridon
   precision guard). **`python3 code/test_matching.py` → 0 failures (must stay 0).**
4. ⚠️ Matcher/schedule changes need the **API server RESTARTED** (it imports `b2g` at startup).

## 6. Flutter app (`code/app/`) — NEW this session
Flutter 3.44.4, platforms **ios,android**. Bundle id `com.brandtogeneric.brandToGeneric`.
- **Theme:** `lib/theme/tokens.dart` (DESIGN.md palette, light+dark) → `app_theme.dart` (`ShadThemeData`
  via `shadcn_ui`) + `context.colors` for semantic families. Geist + Noto Sans Devanagari bundled
  (`assets/fonts/`). App-wide momentum scroll (`AppScrollBehavior` in `main.dart`).
- **Screens (`lib/screens/`):** Capture (home: camera/gallery + privacy line + Settings gear) → Analyzing
  (spinner → OCR → parse → API) → Results (savings strip, bordered drug rows w/ Rx/Schedule-X badges + Jan
  Aushadhi anchor, safety callouts, nearby card, collapsible "Couldn't match N lines"). Mock Results
  reachable as a labelled "sample". **Item detail** (tap a found row: current price, savings, safety
  callout, the FULL cheaper-alternatives ladder w/ Jan Aushadhi flagged, where-to-buy), **Nearby**
  (distance-ranked full list + empty state; honest "turn on location to rank" note), **Settings**
  (appearance/theme, language [English; हिन्दी "coming soon"], privacy, about). Shared widgets in
  `lib/widgets/` (ScreenHeader, NearbyCard, PharmacyRow, SafetyCallout, SectionLabel, Disclaimer, `rupees`).
  `ResultItem` now parses the backend's full `alternatives` list (was dropped).
- **On-device OCR (`lib/services/ocr/`):** `OcrEngine` interface; **Apple Vision** impl via a platform
  channel — native `OcrPlugin` (VNRecognizeTextRequest) in `ios/Runner/AppDelegate.swift`, channel
  `brand_to_generic/ocr`, returns text+confidence+**bbox**. Android/ML Kit would slot in behind the interface.
- **Parser (`lib/services/parser/receipt_parser.dart`):** bounding-box **column detection** (tuned on real
  pharm_5 boxes: name column bounded by its header-row neighbours, since the "Particulars" label is indented)
  + a text heuristic fallback. **Safety net:** column mode is used only if it keeps ≥60% of the heuristic's
  items, so a mis-detection can never silently drop meds. qty defaults to 1 (flat OCR has no columns for it).
- **API client (`lib/services/api/b2g_api.dart`):** HMAC-SHA256 signed `POST /v1/analyze`, **cross-tested
  byte-for-byte vs `b2g.security.sign`** (`test/signing_test.dart`). Sets Content-Length. Models mirror the
  API in `lib/models/analysis.dart` (fromJson) — mock→real is a one-line swap.
- **Config:** `lib/config/api_config.dart` via `--dart-define` (no secrets in repo). Self-signed dev cert
  accepted **only in debug** (`kDebugMode`).
- **Deps:** `shadcn_ui`, `image_picker`, `crypto`. **Tests pass** (widget, parser real-box, signing); `flutter analyze` clean.

### Run the app on a device (dev)
```bash
brew install cocoapods                      # one-time (image_picker has native pods)
# 1) backend on the LAN (defaults to 127.0.0.1 which the phone can't reach):
B2G_HOST=0.0.0.0 python3 code/server.py     # serves https://0.0.0.0:8443 (DB + secrets/ must exist)
# 2) dev secret:
python3 -c "import json;print(json.load(open('secrets/keys.json'))['dev-ee9cdb68'])"
# 3) run on iPhone (same Wi-Fi; Mac LAN IP was 192.168.1.40):
cd code/app && flutter run \
  --dart-define=B2G_API_URL=https://192.168.1.40:8443 \
  --dart-define=B2G_API_KEY=dev-ee9cdb68 \
  --dart-define=B2G_API_SECRET=<paste secret>
```
iOS one-time: set Signing team (free Apple ID) in `ios/Runner.xcworkspace`; trust the dev cert on-device;
free-account apps expire after 7 days (just re-run). Without `--dart-define`s the app still runs and shows
recognized text (no matching). **If "couldn't reach server": the server process likely stopped — restart it (step 1).**

## 7. OCR engine benchmark (`code/ocr_bench/`) — NEW this session
Picks the on-device engine **with evidence**. Stdlib harness, per-engine subprocess (clean peak-RAM),
scores **drug line-item extraction** vs human-verified `gold/*.json` (name/strength weighted; qty/price soft).
Local-only (pharm_5 is a real bill). VLMs run via **llama.cpp GGUF Q8 + `--mmproj` + `--jinja`** (`brew
install llama.cpp`; no torch); docling/granite via a venv (`code/ocr_bench/.venv`). Report at
`output/ocr_bench/report.md`.

**Results (5 receipts):** DeepSeek-OCR **98** (~8s/img, 4GB) & dots.ocr 98 (but ~150s/img) & GLM-OCR 95
[heavy VLMs]; **Apple Vision 90** (244MB, 0.18s) & Tesseract 87 [lightweight]; unlimited_ocr 62 (prompt/GGUF
artifact — needs a fair retry, NOT a true verdict); granite_docling 17 / full-precision 5 & docling-pipeline
48 & moondream 0 (not suited to dense receipts).
**Device-tier picks:** 8GB+ → DeepSeek-OCR · ≤4GB → **Apple Vision (iOS) / ML Kit (Android)** (only ~8 pts
below the VLMs, ~free/instant — a VLM may be overkill for most users) · tiny VLMs don't cut it.
See memory `ocr-engine-strategy.md` + `code/ocr_bench/README.md`. n=5 is thin — widen before locking.

## 8. Design — LOCKED (`writeup/DESIGN.md`)
Neutral shadcn surfaces + one indigo accent; color = meaning (green savings / amber Rx / red Schedule X).
Light default + full dark. Geist + Noto Devanagari. Dense bordered rows, no card-slop. Implemented in §6.

## 9. ⭐ NEXT — what to work on (prioritized; nothing started)
1. **Product screens — DONE** (Item detail, Nearby [list; **map still TODO**], Settings; see §6). Still
   open: wire **Hindi/Devanagari fallback** (font bundled; fallback not yet applied through shadcn's
   single-family text theme — needs `fontFamilyFallback` threaded through, not just `fontFamily: 'Geist'`).
2. **Location — DONE (GPS + address fallback):** `geolocator` + `geocoding` wired. `LocationService`
   (`lib/services/location/`): `currentLatLon()` (best-effort GPS, never throws/blocks; started during OCR so
   the fix overlaps) + `geocode(address)` (OS geocoder, no API key). Analyzing screen passes `{lat,lon}` to
   `analyze()` → server distance-ranks. **Denied GPS?** Results shows a "Find nearby pharmacies" button →
   Nearby screen has an **address search** box → `LocationService.geocode` → `B2gApi.nearby` →
   **`POST /v1/nearby`** (NEW endpoint, signed; body `{location}` → `{pharmacies}`). Both endpoints filter to
   `NEARBY_MAX_KM`=50 (a US point → empty, honestly, vs India-only data). iOS
   `NSLocationWhenInUseUsageDescription` + Android COARSE/FINE perms added; Settings privacy note covers it.
   Still TODO: a **map** view (next). (`flutter run` auto-runs `pod install` for the new plugins.)
3. **Parser polish — qty extraction DONE:** column mode now reads per-line qty from a detected "Qty"
   header, aligned by row, validated 1–99, ambiguity/none → unknown (parser `LineItem.qty` is `int?`,
   omitted from the payload; flat OCR stays unknown). **Backend savings semantics FIXED** (`pipeline.py`):
   `line = savings_per_unit * qty` (was `savings_pack * qty`, which overstated ~pack-size× — a real bug);
   unknown qty falls back to one pack. `qty` is now **optional** in `validate_payload`. Guarded by NEW
   **`python3 code/test_pipeline.py`** (0 failures; keep it so). Still optional: strip the "34.27 |" S.No
   prefix on-device (backend already tolerates it).
4. **On-device OCR productionization:** validate ML Kit on a real Android device; decide if/how to integrate
   the **DeepSeek-OCR VLM tier** for 8GB+ phones (real native lift — Apple Vision is already 90, so likely
   not worth it for v1). The Analyzing screen still has a `[ocrbox]` debug dump (debug builds only) for tuning.
5. **Widen the OCR benchmark** test set (more real receipts) → do the **fair Unlimited-OCR retry** (its 62
   was a detection-mode/community-GGUF artifact, not capability).
6. **Backend coverage — widened (2026-06-27):** ran a coverage probe (NEW **`python3 code/check_coverage.py`**,
   reports match-rate + misses over `ocr_bench/gold/`; real items now 17/24, the rest are generic
   descriptions / homeopathy / packaging / Saridon). Finding: the open catalog is already broad — most
   common brands have SKUs. Added verified absent-but-composition-present aliases: **doxozest→doxorubicin**
   (real pharm_4 miss), **disprin→aspirin** (limcee→vitamin c was REJECTED — only injectable 500mg under
   that salt). **Route-safety fix:** `_composition_match` is now **form-aware** — an alias/generic lookup
   returns a SAME-ROUTE representative (never an injectable for an oral tablet); formless queries prefer oral
   and never fall back to a parenteral. Guarded by a ROUTE_OK block in `test_matching.py`. Still open: generic
   typo-tolerant fuzzy for OCR garbles that DELETE internal chars (HQS↔HCQS — needs a brand/trigram index,
   not prefix blocking; currently per-brand alias). Saridon's propyphenazone is genuinely absent (data, not code).
7. **Safety — gazette reconciliation DONE (2026-06-27):** H1/X salt lists reconciled vs the official
   Drugs & Cosmetics Rules Schedule X (16) + H1 (46 + oxytocin/tapentadol). Fixed under-flags
   (phenobarbitone/phenytoin→H, clofazimine/oxytocin/tapentadol→H1, levofloxacin→H1), over-flags
   (cefuroxime/sulbactam/tigecycline H1→H), and a substring collision (phenobarbital must NOT be X).
   Conservative overrides documented (clonazepam/lorazepam/zopiclone H1; methaqualone X). Full writeup +
   sources: `writeup/SAFETY_AUDIT.md`. Guarded by NEW **`python3 code/test_safety.py`** (0 failures).
   Ran `recompute_schedule.py` (6000 rows). Still open: `_SALTS_H` stays non-exhaustive (demand-driven).
8. **Gold sync:** apply the corrections already in `code/ocr_bench/gold/` back to `code/ocr_samples/`
   (pharm_1 NS qty 2→3; pharm_5 PREGEB/FLEXON MRPs) so the pipeline benchmark agrees.
9. **Production hardening:** real TLS cert + cert pinning in release (debug accepts self-signed), per-install
   API keys + rotation, reverse proxy; fuller pharmacy coverage; NPPA prices (deferred — Jan Aushadhi covers generics).
10. **App store path:** Android signing + test device; revisit iOS bundle id if the free Apple ID collides.

## 10. Known-good invariants (don't regress)
- `python3 code/test_matching.py` → **0 failures** (precision guard: Saridon must-not-match + ROUTE_OK
  oral/injectable never cross). `python3 code/check_coverage.py` reports real-receipt match-rate (informational).
- `python3 code/test_pipeline.py` → **0 failures** (savings never overstate: line = per_unit × qty, not
  per-pack × qty; unknown qty → one pack).
- `python3 code/test_safety.py` → **0 failures** (H/H1/X gazette reconciliation incl. phenobarbital-not-X
  guard + conservative overrides). After editing `b2g/schedule.py`, re-run `recompute_schedule.py`.
- `cd code/app && flutter analyze` clean; `flutter test` green (widget + parser real-box + signing +
  screens smoke tests; 10 total).
- `code/app/lib/data/sample_result.dart` IS tracked — the `.gitignore` `data/` rule is now root-anchored
  (`/data/`) so it no longer swallows app source. Don't revert that anchor (a fresh clone wouldn't build).
- Dart request signature == `b2g.security.sign` (the signing test pins this — a mismatch = silent 401s).
- Column detection must never drop meds (the ≥60%-of-heuristic safety net enforces this).

## 11. Rebuild the catalog (only if `data/b2g.db` is missing)
```bash
mkdir -p data/raw && curl -L -o data/raw/indian_medicine_data.csv \
  https://raw.githubusercontent.com/junioralive/Indian-Medicine-Dataset/main/DATA/indian_medicine_data.csv
python3 code/ingest.py                 # base catalog
curl -s -X POST -H 'Content-Type: application/json' -H 'Referer: https://janaushadhi.gov.in/' \
  -d '{"pageIndex":0,"pageSize":3000,"searchText":"","orderBy":"asc","columnName":"genericName"}' \
  'https://janaushadhi.gov.in:8443/api/v1/admin/product/getAllProductForWeb' \
  -o data/raw/janaushadhi_products.json
python3 code/ingest_janaushadhi.py     # official prices (AFTER ingest.py)
python3 code/ingest_pharmacies.py      # real nearby pharmacies (OSM)
python3 code/recompute_schedule.py     # apply the current salt lists (DMARD fix) to the schedule column
```
NOTE: `ingest.py` rebuilds from scratch — always run the janaushadhi + pharmacies + recompute steps after.

## 12. Key docs, memory, git
- Docs: `writeup/DESIGN.md` · `SPEC.md` · `ARCHITECTURE.md` · `API_DESIGN.md` · `BENCHMARK.md` · `TODO.md` ·
  `code/ocr_bench/README.md`.
- **Memory** (`~/.claude/projects/-Users-a4r4-projects-brand-to-generic/memory/`): `project-brand-to-generic`,
  `feedback-basic-libraries-no-pandas`, **`ocr-engine-strategy`**, **`flutter-app-state`** (run recipes + state).
- **Git:** branch `main`. **This session's work is largely uncommitted** (app, ocr_bench, schedule/matcher/test
  changes, recompute_schedule.py). Commit as `Aarav <aarav10a1@gmail.com>`, **no `Co-Authored-By` trailer**.

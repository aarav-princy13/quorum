# Session transfer — brand_to_generic

**Updated:** 2026-06-25 · Single entry point for continuing this project in a new session.
Read this first, then the docs it links. Owner: **Aarav**.

---

## 1. What this is
An India-focused app: **scan a pharmacy receipt → OCR on-device → flag prescription-only /
abuse-prone drugs (Schedule H/H1/X) → find cheaper *generic* equivalents + official Jan Aushadhi
prices + nearby pharmacies.** Goal: help cost-conscious patients pay less for the same medicine,
safely.

## 2. Current state (one line)
**Backend = built, tested, and validated on real receipts. Design = locked & specified. The
Flutter app is NOT yet scaffolded — that's the next task.**

## 3. Hard constraints / owner preferences (don't violate)
- **Python: standard library only. NO pandas / heavy deps** unless justified + approved.
- **Privacy:** the receipt *image* is OCR'd on-device and never uploaded — only extracted text.
- **Git:** author `Aarav <aarav10a1@gmail.com>`, **NO `Co-Authored-By` trailer**. Commit when work lands.
- Owner values: methodical, evidence-first (measure before assuming), honest about limitations,
  precision over recall on matching (a wrong drug is worse than a miss).

## 4. Repo layout
```
code/        Python backend (stdlib). b2g/ package + scripts.
output/      generated artifacts (gitignored bulk)
writeup/     all the thinking: SPEC, MARKET_RESEARCH, ARCHITECTURE, DATA_SOURCES,
             DATA_CLEANING, API_DESIGN, BENCHMARK, DESIGN, TODO, SESSION
data/        (gitignored) raw downloads + built SQLite b2g.db
secrets/     (gitignored) dev API key + self-signed TLS cert
session_transfer.md   ← you are here
```
`pharm_*` receipt images and `data/` + `secrets/` are gitignored.

## 5. Backend — what's built (all in `code/`)
- **Catalog DB** `data/b2g.db` (gitignored; rebuild below): open Indian Medicine Dataset (~246k
  products) + **official Jan Aushadhi prices** (~2,052, `is_authoritative=1`).
- **Package `code/b2g/`:** `db`, `normalize` (salt/strength canonicalization), `schedule`
  (H/H1/X + `schedule_for(salt, form)` parenteral fallback), `matcher` (the brains), `pipeline`,
  `report`, `util` (pack units + haversine), `security` (HMAC + rate limit).
- **Matching** (`matcher.py`), precision-first: exact → **salt-lookup** (generic names → plain
  composition) → prefix → **fuzzy** (`difflib`). Guards: unit-aware strengths (1gm=1000mg),
  pack-size-aware (topical 5GM ≠ dose), discriminator guard (Vitamin C ≠ A), brand-token scoring,
  median outlier floor. **0 wrong matches** on the 17-case `code/test_matching.py`.
- **Savings:** cheapest same-composition + same-form, per-unit; **Jan Aushadhi authoritative
  anchor** shown (exempt from outlier floor).
- **Nearby pharmacies:** REAL OpenStreetMap data (`ingest_pharmacies.py`), ranked by haversine distance.
- **Secure HTTPS API** (`server.py`): TLS, **API key + HMAC signing with per-request nonce**
  (replay/tamper resistant), **rate-limit per key + IP**, strict input caps, no-content logging,
  read-only DB. `client_example.py` is the signed-request blueprint (port to Dart).
- NPPA prices: investigated, PDF/portal-locked → **deferred** (Jan Aushadhi covers generic prices).

### Run it
```bash
# rebuild catalog (downloads ~32MB once):
mkdir -p data/raw && curl -L -o data/raw/indian_medicine_data.csv \
  https://raw.githubusercontent.com/junioralive/Indian-Medicine-Dataset/main/DATA/indian_medicine_data.csv
python3 code/ingest.py                 # base catalog
curl -s -X POST -H 'Content-Type: application/json' -H 'Referer: https://janaushadhi.gov.in/' \
  -d '{"pageIndex":0,"pageSize":3000,"searchText":"","orderBy":"asc","columnName":"genericName"}' \
  'https://janaushadhi.gov.in:8443/api/v1/admin/product/getAllProductForWeb' \
  -o data/raw/janaushadhi_products.json
python3 code/ingest_janaushadhi.py     # official prices (run AFTER ingest.py)
python3 code/ingest_pharmacies.py      # real nearby pharmacies (OSM)

python3 code/demo.py                   # seed demo
python3 code/query.py "Telma 40" "Pan 40 Tablet"   # real-DB query
python3 code/test_matching.py          # matching regression (must PASS)
python3 code/ocr_bench.py              # receipt benchmark (fixtures in code/ocr_samples/)
# API: python3 code/gen_secrets.py && python3 code/server.py ; then code/client_example.py
```
NOTE: `ingest.py` rebuilds the DB from scratch — always run `ingest_janaushadhi.py` then
`ingest_pharmacies.py` after it.

## 6. Design — LOCKED (see `writeup/DESIGN.md` for the full spec + token table)
- Neutral shadcn surfaces + **one indigo accent** (`#4F46E5` light / `#6366F1` dark). Color =
  meaning only: **green = savings, amber = Rx (H/H1), red = Schedule X/strict.**
- **Light default + full dark.** Type: **Geist** (Latin, bundled) + **Noto Sans Devanagari** (Hindi).
- **`shadcn_ui`** Flutter kit. Dense **bordered rows** (no card-slop). Follow impeccable's slop-bans.
- App lives in **`code/app/`**. Screens: capture → analyzing → results → item detail → nearby → settings.
- Reference mockups were rendered in-chat (results screen, style tile, accent/Hindi comparison).

## 7. Benchmark status (`writeup/BENCHMARK.md`)
5 receipts in `code/ocr_samples/` (pharm_1–4 internet-sourced, **pharm_5 = a REAL Sant Pharmacy
bill**). Latest run: **24 items, 13 matched, 6 Rx-flagged**. Matching held up on the real messy
photo. The four earlier findings (#1 unit, #2 pack-size, #3 schedule injectables, #4 plain-vs-combo)
are all **fixed + regression-tested**.

**Open finding from pharm_5 (HIGH-PRIORITY, safety):** `LEFRA` (leflunomide) and `HCQS`
(hydroxychloroquine) matched but show **[OTC]** — both are prescription-only DMARDs. Fix: add
DMARDs/specialty Rx salts (leflunomide, hydroxychloroquine, sulfasalazine, azathioprine,
mycophenolate, tofacitinib, …) to `_SALTS_H` in `code/b2g/schedule.py`, then re-ingest. Also a few
common-brand coverage misses (Saridon, Crocin 650, Shelcal, Evion) worth investigating.

## 8. ⭐ NEXT TASK — scaffold the Flutter app
1. **Install Flutter first** (it is NOT installed; Xcode 27 IS present):
   `brew install --cask flutter` → `flutter doctor`. Test devices: iPhone 13 + 15 (free Apple ID
   ok), Android TBD. The M4 Pro Mac can also run the dev-side VLM-OCR benchmark locally (MLX).
2. `flutter create code/app` and implement **`writeup/DESIGN.md`** verbatim: theme from the token
   table (light+dark, `ShadThemeData`), bundle Geist + Noto Sans Devanagari fonts, build screens
   with **mock data first** (use the benchmark fixtures / a sample result), then wire:
   - **Dart API client** porting `code/client_example.py` HMAC signing (use `crypto` for HMAC-SHA256).
   - **On-device OCR seam** (`google_mlkit_text_recognition`) → parse line items → POST to backend.
3. Quick win to do alongside: the **DMARD safety fix** (§7) — small, safety-relevant.

## 9. Skills installed (this session)
`impeccable` (`/impeccable`) + `taste-skill` sub-skills (`/minimalist-ui`, `soft`, `brandkit`,
`redesign`, …) at `~/.claude/skills/`. They're **web-oriented** — use for design *taste/critique*,
not Flutter code-gen. impeccable's per-edit hook was **disabled** for this repo
(`.claude/settings.local.json`; re-enable with `npx impeccable install --scope=project`).

## 10. Prioritized open TODO (full list in `writeup/TODO.md`)
1. **Safety:** add DMARD/specialty Rx salts to `_SALTS_H` (pharm_5 gap).
2. **Scaffold the Flutter app** (§8) — the main thrust.
3. pharm_5 coverage misses (Saridon/Crocin 650/Shelcal/Evion).
4. Validate curated H1/X lists vs the official gazette.
5. On-device OCR engine benchmark (ML Kit vs Granite-Docling via MLX) once the app shell exists.
6. NPPA prices (deferred), fuller pharmacy coverage, production API hardening (reverse proxy, key rotation).

## 11. Key docs
`writeup/DESIGN.md` (app design spec) · `writeup/SPEC.md` (product) · `writeup/ARCHITECTURE.md` ·
`writeup/MARKET_RESEARCH.md` · `writeup/DATA_SOURCES.md` · `writeup/DATA_CLEANING.md` ·
`writeup/API_DESIGN.md` · `writeup/BENCHMARK.md` · `writeup/TODO.md` · `writeup/SESSION.md` (full log).
Persistent memory lives under `~/.claude/projects/-Users-a4r4-projects-brand-to-generic/memory/`.

## 12. Git
Branch `main`. Recent: `e517ac7` design spec · `fe61c4f` #2/#4 fixes · `55a22db` safety pair ·
`f9ef3d6` secure API. Commit as `Aarav <aarav10a1@gmail.com>`, no co-author trailer.

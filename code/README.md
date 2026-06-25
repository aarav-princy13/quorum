# code/ — Python backend

Pure standard library (`sqlite3`, `csv`, `json`, `re`, `statistics`). **No pandas, no third-party deps.**

## Quick start
```bash
# 1) Zero-setup demo on tiny illustrative seed data:
python3 code/demo.py

# 2) Real catalog (~246k Indian medicines). Download once, then build + query:
mkdir -p data/raw && curl -L -o data/raw/indian_medicine_data.csv \
  https://raw.githubusercontent.com/junioralive/Indian-Medicine-Dataset/main/DATA/indian_medicine_data.csv
python3 code/ingest.py                                   # builds data/b2g.db (~60 MB, a few sec)

# 3) Layer in OFFICIAL Jan Aushadhi prices (authoritative). Fetch once, then ingest:
curl -s -X POST -H 'Content-Type: application/json' -H 'Referer: https://janaushadhi.gov.in/' \
  -d '{"pageIndex":0,"pageSize":3000,"searchText":"","orderBy":"asc","columnName":"genericName"}' \
  'https://janaushadhi.gov.in:8443/api/v1/admin/product/getAllProductForWeb' \
  -o data/raw/janaushadhi_products.json
python3 code/ingest_janaushadhi.py                       # adds authoritative rows (run AFTER ingest.py)

python3 code/query.py                                    # sample receipt
python3 code/query.py "Telma 40 Tablet" "Pan 40 Tablet"  # shows the ✓Jan Aushadhi anchor

# 4) Real nearby pharmacy locations from OpenStreetMap (default: Chandigarh, 16 km):
python3 code/ingest_pharmacies.py
```
Note: `ingest.py` rebuilds the DB from scratch, so always run `ingest_janaushadhi.py` and
`ingest_pharmacies.py` after it (in that order).
Outputs are written to `output/` (`*_result.json`, `*_report.txt`).

## Layout
```
code/
  schema.sql          SQLite schema (drugs, pharmacies)
  seed_data/          tiny sample CSVs (illustrative — NOT real prices)
  b2g/                the backend package
    db.py             connect / build schema / load + normalize seed
    util.py           pack-size -> unit-count parsing
    normalize.py      salt/strength canonicalization (safe synonym + qualifier folding)
    schedule.py       Schedule H/H1/X classification (salt-based) + Rx rule
    matcher.py        brand -> salt+strength -> cheaper SAME-FORM equivalents (per-unit)
    pipeline.py       receipt line items -> per-item results + summary; nearby lookup
    report.py         text rendering of a result
  ingest.py           build data/b2g.db from the real dataset CSV (open data)
  ingest_janaushadhi.py  layer in OFFICIAL Jan Aushadhi prices (authoritative)
  ingest_pharmacies.py   real nearby pharmacy locations from OpenStreetMap (Overpass)
  analyze_salts.py    review tool: surface candidate salt variants for the synonym map
  demo.py             end-to-end demo on seed data
  query.py            query the real DB with brand names
  test_matching.py    regression tests for name matching (precision + safety)
  b2g/security.py     HMAC auth (replay-resistant) + token-bucket rate limiting
  server.py           secure HTTPS API over the pipeline
  gen_secrets.py      mint a dev API key + self-signed TLS cert
  client_example.py   reference signed client (blueprint for the Flutter client)
```

## Secure API server
```bash
python3 code/gen_secrets.py          # one-time: dev API key + self-signed cert (secrets/, gitignored)
python3 code/server.py               # HTTPS on 127.0.0.1:8443
python3 code/client_example.py "Telma 40" "Pan 40 Tablet"   # signed request
```
`POST /v1/analyze` body `{items:[{name,qty}], location?:{lat,lon}}` → matches + savings +
H/H1/X safety + nearby pharmacies. `GET /v1/health` → liveness. **The receipt image is never
sent — only text** (OCR is on-device).

Security (see [../writeup/API_DESIGN.md](../writeup/API_DESIGN.md)): TLS; **API key + HMAC
signing with a per-request nonce** (replay/tamper resistant, constant-time check, ±300 s
window); **rate limiting per key AND per IP** (+ global concurrency cap); strict input caps
(16 KB / 50 items); **no-content logging** (no drug names logged); read-only DB; generic
errors and no server banner. NOTE: stdlib `http.server` should still sit behind nginx/Caddy in
production.

## Name matching (exact → prefix → fuzzy)
Receipt names are messy (`Glycomet 500 Tablet`, `Pan 40 Tab`, `Telma40`). Matching tries
exact, then prefix, then a conservative **stdlib `difflib`** fuzzy match. Precision is
prioritized over recall — a wrong drug/strength is worse than a miss — via two guards:
- **Discriminator guard:** every distinguishing token (strength numbers, single letters like
  the vitamin in `Vitamin C`, `b12`/`d3`) must appear in the candidate, so `Vitamin C` never
  matches `Vitamin A` and `Glycomet 500` never matches the combo `Glycomet-GP 1`.
- **Score threshold** (`matcher.FUZZY_THRESHOLD`); below it we report "not found" rather than guess.
Fuzzy matches are flagged `≈ approx match` in the report so the user can verify.
Run `python3 code/test_matching.py` for the regression suite.

## Authoritative prices (Jan Aushadhi)
Official PMBJP prices are ingested as `is_authoritative=1` rows. They are **exempt from the
outlier floor** (govt-subsidized prices are genuinely low and verified) and surfaced in the
report as a **✓Jan Aushadhi (govt)** anchor — either as the recommended option or as an
official reference alongside the cheapest market option.

## Data-quality safeguards (see writeup/DATA_CLEANING.md)
- **Canonicalization** — salts/strengths folded for spelling, pharmacopoeia qualifiers
  (ip/bp/usp) and a curated cross-source synonym map; **never** merges distinct salt forms
  (succinate vs tartrate stay separate).
- **Unknown-dose guard** — products with no parseable strength (`strength_known = 0`) are
  matched but never offered as a substitute.

## How the matching stays honest
- **Same composition AND same form** — a tablet is never substituted by an injection.
- **Per-unit pricing** — pack MRP is divided by unit count, so "strip of 10" isn't
  compared naively against a single tablet.
- **Outlier floor** — same-composition prices below 20% of the median are dropped as
  likely data-entry errors (see `matcher.OUTLIER_FLOOR_FRAC`).

## How it fits the architecture
This backend receives **text only** (line items), never the receipt image — the image
is OCR'd on-device in the Flutter app (privacy decision). See
[../writeup/ARCHITECTURE.md](../writeup/ARCHITECTURE.md).

## What's stubbed / next
- Seed data is tiny & illustrative. Next: ingest real **Jan Aushadhi / NPPA / open
  composition** data into SQLite (see [../writeup/DATA_SOURCES.md](../writeup/DATA_SOURCES.md)).
- Name matching is simple (exact/prefix). Real OCR text needs fuzzy matching.
- No HTTP layer yet — can wrap with stdlib `http.server` when the app needs an API.

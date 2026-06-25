# code/ — Python backend

Pure standard library (`sqlite3`, `csv`, `json`, `re`). **No pandas, no third-party deps.**

## Run the demo
```bash
python3 code/demo.py
```
It builds an in-memory SQLite DB from the seed data, runs a simulated OCR'd receipt
through the pipeline, prints a report, and writes `output/demo_result.json` +
`output/demo_report.txt`.

## Layout
```
code/
  schema.sql          SQLite schema (drugs, pharmacies)
  seed_data/          tiny sample CSVs (illustrative — NOT real prices)
    drugs.csv
    pharmacies.csv
  b2g/                the backend package
    db.py             connect / build schema / load seed CSVs
    schedule.py       Schedule H/H1/X classification + Rx-confirmation rule
    matcher.py        brand name -> salt+strength -> cheaper equivalents + savings
    pipeline.py       receipt line items -> per-item results + summary; nearby lookup
  demo.py             end-to-end runnable demo
```

## How it fits the architecture
This backend receives **text only** (line items), never the receipt image — the image
is OCR'd on-device in the Flutter app (privacy decision). See
[../writeup/ARCHITECTURE.md](../writeup/ARCHITECTURE.md).

## What's stubbed / next
- Seed data is tiny & illustrative. Next: ingest real **Jan Aushadhi / NPPA / open
  composition** data into SQLite (see [../writeup/DATA_SOURCES.md](../writeup/DATA_SOURCES.md)).
- Name matching is simple (exact/prefix). Real OCR text needs fuzzy matching.
- No HTTP layer yet — can wrap with stdlib `http.server` when the app needs an API.

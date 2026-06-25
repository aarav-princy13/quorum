# Drug & Pharmacy Data Sources

**Date:** 2026-06-24 · Owner asked for advice (no strong prior). Recommendation below.

## The core data model
```
brand name (scanned)  ──▶  salt + strength  ──▶  all products with same salt+strength  ──▶  cheapest = generic
                              (composition DB)        (catalog)                              savings = brand MRP − generic price
```
Plus a separate **Schedule H/H1/X** lookup for the safety warning.

## Recommended source stack (assemble locally into SQLite)
| Need | Source | Type / access | License / caveat |
|------|--------|---------------|------------------|
| **Brand → salt + strength** (hardest) | A-Z Medicine Dataset of India (~250K products, has composition); GitHub `junioralive/Indian-Medicine-Dataset` | Open dataset (Kaggle/GitHub), CSV | Verify license before commercial use; treat as prototype data |
| Brand → salt (alt, do NOT ship commercially) | 1mg dataset (~300K rows) | Kaggle CSV | **CC BY-NC-SA 4.0 = non-commercial only.** Dev/eval reference only |
| **Generic alternative + price** | Jan Aushadhi / PMBJP product list (~1,616 generics) | Official PDF + portal `janaushadhi.gov.in/productlist.aspx` | No clean API → parse PDF/portal; official & free |
| **Brand MRP / ceiling price** | NPPA DPCO ceiling prices (~907 scheduled, rev. Apr 2026) | Official portal `nppaimis.nic.in`, PDFs | Scheduled formulations only; no CSV/API → scrape/parse |
| **Schedule H/H1/X classification** | Official Drugs & Cosmetics schedules (compile to lookup table) | Manual/curated | Authoritative; small, stable list |
| **Nearby pharmacies (locations-only)** | Maps provider (Google Places / OpenStreetMap) + Jan Aushadhi Kendra directory | API | Locations only in MVP; no live inventory |

## Recommendation (what to actually do)
1. **Prototype now:** ingest an **open composition dataset** (brand→salt) + **Jan Aushadhi** generics + **NPPA** prices into **SQLite** using stdlib `csv`/`sqlite3` (no pandas). One small ingestion script per source.
2. **Schedule list:** hand-compile H/H1/X into a lookup table (small, rarely changes).
3. **Before commercial launch:** replace/verify any non-commercially-licensed data (esp. 1mg); consider licensing a curated drug DB for the salt-mapping (production reliability + liability).
4. **Pharmacy locations:** start with a maps API + the Jan Aushadhi Kendra directory; live inventory waits for partnerships (Phase 3).

## Status — what's ingested
- **Open Indian Medicine Dataset** (`junioralive/Indian-Medicine-Dataset`, ~254k rows) →
  `data/b2g.db` via `code/ingest.py` (stdlib). **246,068 products, ~10,900 compositions** —
  the brand→composition→price layer.
- **Jan Aushadhi / PMBJP official prices (AUTHORITATIVE)** → via `code/ingest_janaushadhi.py`.
  **2,052 priced products**, of which **~950 match an existing brand composition+form** and
  give **1,572 distinct authoritative anchors**. Marked `is_authoritative=1`, `source='janaushadhi'`.
- **Schedule H/H1/X** from a curated salt list (`b2g/schedule.py`); H1/X reliable, H partial.
- **Savings** computed by same-composition + same-form, per-unit; official prices are
  exempt from the outlier floor and surfaced as a trusted anchor.
- **Nearby pharmacies (REAL)** → via `code/ingest_pharmacies.py` from the **OpenStreetMap
  Overpass API** (neutral: any pharmacy, Jan Aushadhi tagged). Stored with lat/lon; the
  pipeline ranks by real great-circle distance (`haversine_km`). Caveat: **OSM pharmacy
  coverage in India is sparse** (~15 mapped in the Chandigarh tricity) — real but incomplete;
  production would use Google Places or the Jan Aushadhi Kendra directory for fuller coverage.
  (Overpass needs a User-Agent header, else it returns 406.)

### How the Jan Aushadhi data was obtained (reproducible)
The official site is a React SPA; its product list comes from a public JSON API on **port 8443**
(found via the page's `Content-Security-Policy` `connect-src`). It needs a POST with pagination:
```
curl -s -X POST -H 'Content-Type: application/json' -H 'Referer: https://janaushadhi.gov.in/' \
  -d '{"pageIndex":0,"pageSize":3000,"searchText":"","orderBy":"asc","columnName":"genericName"}' \
  'https://janaushadhi.gov.in:8443/api/v1/admin/product/getAllProductForWeb'
```
Returns `responseBody.newProductResponsesList[]` with `genericName, groupName, unitSize, mrp`.
(The same API has `getNearByKendra` — useful for real nearby-pharmacy locations later.)

### NPPA — investigated, currently blocked
NPPA ceiling prices are **not cleanly auto-ingestable** stdlib-only: `nppa.gov.in` is a
server-rendered CMS with prices in **gazette PDFs**; `nppaimis.nic.in` is an old ASP.NET
search portal (viewstate); the `data.gov.in` API needs a registered key. Realistic paths:
(a) a registered data.gov.in key if an NPPA price resource exists, (b) a PDF-parsing dependency
(needs approval — violates stdlib-only), or (c) a small curated subset. **Deferred.** Note:
Jan Aushadhi prices are typically at/below NPPA ceilings, so the generic-price layer is covered;
NPPA would mainly add a brand-price *ceiling* for validation.

## Known data-quality issues (open dataset)
- **Price outliers / data-entry errors** (e.g. per-tablet price entered as per-strip) →
  mitigated with a median-based outlier floor in `matcher.py`, but real cleaning needs
  authoritative NPPA/Jan Aushadhi prices.
- **Salt spelling variants** — investigated empirically (see **DATA_CLEANING.md**): the
  dataset is already salt-consistent, so a synonym map is a near-no-op now but is in place
  (`b2g/normalize.py`) for cross-source merging later.
- **Missing/junk doses** (1.4%) — now flagged `strength_known = 0` and excluded from
  substitution recommendations (safety).
- **License unspecified upstream** → prototype use only; verify before commercial.

## Risks
- **Salt-mapping accuracy & licensing** is the make-or-break data risk (wrong substitution = safety issue).
- Government data is **PDF/portal-locked** (no APIs) → parsing/maintenance burden; prices drift (NPPA revises ~yearly).
- Must keep **disclaimers**: suggestions are informational; confirm with a pharmacist/doctor.

## Sources
- https://nppa.gov.in/en — NPPA
- https://nppaimis.nic.in/nppaprice/newmedicinepricesearch.aspx — NPPA price search (DPCO 2013)
- https://janaushadhi.gov.in/productlist.aspx — Jan Aushadhi product list
- https://janaushadhi.gov.in/Data/PMBJP%20Product.pdf — PMBJP product PDF
- https://github.com/junioralive/Indian-Medicine-Dataset — open Indian medicine dataset
- https://www.kaggle.com/datasets/shudhanshusingh/az-medicine-dataset-of-india — A-Z dataset (~250K, composition)
- https://www.kaggle.com/datasets/apkaayush/india-medicines-and-drug-info-dataset — India medicines dataset

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

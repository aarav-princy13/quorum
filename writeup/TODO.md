# TODO

## Phase 0 — Discovery (in progress)
- [x] Market & competitor research (see MARKET_RESEARCH.md)
- [x] Feasibility verdict (feasible; gap = receipt-scan + neutral nearby finder)
- [x] Set up repo, dirs, and capture docs
- [x] Owner answered round 1 (cross-platform, on-device privacy, no Tesseract, locations-only, warn+confirm-Rx)
- [x] Architecture research + ARCHITECTURE.md (2026 OCR/VLM landscape)
- [ ] **Owner to answer round 2** (framework, privacy boundary, OCR engine, drug-data source)

## Phase 1 — Foundations
- [x] Scaffold `code/` (Python backend, stdlib + SQLite, no pandas) — runnable `demo.py`
- [x] Build Schedule H/H1/X classification lookup (`b2g/schedule.py`, warn + confirm Rx)
- [x] Core pipeline: receipt line items → generic match + savings + safety (validated on sample)
- [x] Decide drug-data approach → `DATA_SOURCES.md`
- [ ] Assemble **real** brand→generic salt/strength + MRP into SQLite (Jan Aushadhi + NPPA + open composition dataset)
- [ ] Harden brand-name matching (fuzzy) for messy OCR text
- [ ] **Benchmark OCR engines on 5–10 real Indian pharmacy receipts** (ML Kit vs Granite-Docling vs small VLM)
- [ ] (optional) stdlib `http.server` API layer so a client can call the pipeline

## Phase 2 — Core pipeline
- [ ] Brand→generic mapping engine + savings calculation
- [ ] Safety/abuse flagging + warning UX
- [ ] Nearby-pharmacy lookup (data source TBD)

## Phase 3 — Product
- [ ] End-to-end demo: receipt photo → savings + nearby options
- [ ] Disclaimers / legal review of safety + facilitation claims
- [ ] Single-city pilot

## Parking lot / risks to revisit
- [ ] Live pharmacy inventory — partnership strategy
- [ ] Regulatory: confirm informational-only model avoids D&C Act online-sale issues
- [ ] OCR accuracy benchmark target

# TODO

## Phase 0 — Discovery (in progress)
- [x] Market & competitor research (see MARKET_RESEARCH.md)
- [x] Feasibility verdict (feasible; gap = receipt-scan + neutral nearby finder)
- [x] Set up repo, dirs, and capture docs
- [x] Owner answered round 1 (cross-platform, on-device privacy, no Tesseract, locations-only, warn+confirm-Rx)
- [x] Architecture research + ARCHITECTURE.md (2026 OCR/VLM landscape)
- [ ] **Owner to answer round 2** (framework, privacy boundary, OCR engine, drug-data source)

## Phase 1 — Foundations (after round-2 decisions)
- [ ] Scaffold `code/` (Python backend, stdlib + SQLite, no pandas)
- [ ] Assemble brand→generic salt/strength + MRP dataset (NPPA / Jan Aushadhi / CDSCO) into SQLite
- [ ] Build Schedule H/H1/X classification lookup
- [ ] **Benchmark OCR engines on 5–10 real Indian pharmacy receipts** (ML Kit vs Granite-Docling vs small VLM)
- [ ] Desktop Python prototype: receipt image → line items → generic + savings (validate core before mobile)

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

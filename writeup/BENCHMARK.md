# Receipt Benchmark — first real-receipt run

**Date:** 2026-06-25 · 4 real (internet-sourced) receipts, mixed formats (webp/jpg/png).

## Method & honest scope
Line items were extracted from each receipt image by a **vision model** (the VLM-OCR path —
what an on-device VLM like Granite-Docling would produce), saved as fixtures in
`code/ocr_samples/*.json`, then run through the real pipeline via `code/ocr_bench.py`.
This measures the **pipeline** (match → savings → safety) on messy real names. A true
on-device **OCR-engine** comparison (ML Kit vs Granite-Docling latency/accuracy) needs the
mobile harness and is **not** done here. Also: several receipts were low-resolution and needed
crop+upscale to read — real-world OCR will face the same quality problem.

## Result (headline is misleading — categorize)
12 line items · **2 matched · 10 not found**. But the misses split into *correct* and *gaps*:

| Item (receipt) | Outcome | Verdict |
|---|---|---|
| REMDAC 100MG INJ (p1) | matched → remdesivir 100mg, **tagged OTC** | ⚠ matched but unsafe schedule label |
| MEPEM 1GM INJ (p1) | not found — but `Mepem 1000mg Injection` IS in catalog | ✗ **bug: 1gm≠1000mg** |
| NS 100ML (p1) | not found | ✓ correct (IV fluid, not a substitution target) |
| INFLORIN 5K INJ (p1) | not found | ~ acceptable (niche) |
| Paracetamol 500 mg (p2) | matched → **caffeine+paracetamol** combo | ⚠ **precision: plain matched a combo** |
| Cough Syrup (200ml) (p2) | not found | ✓ correct (generic descriptor, no salt) |
| Antibiotic Cream (30g) (p2) | not found | ✓ correct (generic descriptor) |
| Belladonna 30 (p3) | not found | ✓ correct (homeopathy; we cover allopathy) |
| 1/2 dram plastic (p3) | not found | ✓ correct (non-drug / packaging) |
| MUPIKEM OINT 5GM (p4) | not found — but `Mupikem Cream` IS in catalog | ✗ **bug: pack-size "5GM" required** |
| CLOCIP DUST POW 75GM (p4) | not found — but `Clocip Cream` IS in catalog | ✗ **bug: pack-size "75GM"; also form** |
| DOXOZEST INJ 50MG (p4) | not found — `doxozest` absent from dataset | ~ real coverage gap |

So: 2 matched, ~5 correct safe non-matches, **~4 fixable gaps**, 1 coverage gap. The branded
drugs that *should* have matched (Mepem, Mupikem, Clocip) ARE in the catalog — they were lost
to two specific, fixable matching bugs.

## Findings → concrete fixes
1. **Unit-blind discriminator** (`1gm` vs `1000mg`): make numeric matching unit-aware
   (gm→×1000, mcg→÷1000) so `1gm == 1000mg`. *Fixes Mepem (an H1 drug — important).*
2. **Pack-size tokens treated as strength** (`5GM`, `75GM`, `100ML` on ointments/powders):
   don't require pack-size numbers as discriminators; distinguish them from dose strengths.
   *Fixes Mupikem, Clocip.* (Form also differs — ointment vs cream — revisit form strictness.)
3. **Safety: schedule list misses hospital/injectable drugs** (remdesivir, meropenem,
   doxorubicin → shown OTC). Expand the curated H/H1/X salts, and/or default
   injectables/antivirals/oncology to prescription-only. *Safety-critical.*
4. **Plain-vs-combo precision**: a plain generic query (`Paracetamol 500 mg`) prefix-matched a
   caffeine combo. Prefer the simplest same-strength composition for generic-name queries.
5. **Coverage**: the open dataset misses some brands (Doxozest). Authoritative/curated sources
   would help; an honest "not found" is the safe fallback meanwhile.

## Fixes applied (2026-06-25, safety pair)
- **#1 unit-blind discriminator → FIXED.** Matching is now unit-aware (`_strength_sigs`:
  1gm = 1000mg = bare 1000). `MEPEM 1GM INJ` now matches `Mepem 1000mg Injection` →
  meropenem, correctly flagged **H1**. Also added a brand-token score bonus so exact-brand
  matches survive format noise (`inj` vs `injection`).
- **#3 schedule misses injectables → FIXED.** Expanded the curated salt list (antivirals incl.
  remdesivir, cytotoxics, injectable antibiotics, anticoagulants) and added a **parenteral-form
  fallback** (`schedule_for(salt, form)`: unrecognised injection/infusion → prescription-only).
  `REMDAC → remdesivir` now flags **H** (was OTC). Verified: oral OTC drugs stay OTC.
- Result: benchmark 2→3 matched, Rx-flagged 0→2; `test_matching.py` still PASS (0 wrong).

## Fixes applied (2026-06-25, #2 + #4)
- **#2 pack-size tokens → FIXED.** On topical/powder queries a gram/ml amount in the name is
  the tube/bottle PACK SIZE, not a dose — `_strength_sigs(drop_pack=...)` now ignores it (but
  keeps gm/mg as the dose on injections). `MUPIKEM OINT 5GM` → mupirocin (54% off),
  `CLOCIP DUST POW 75GM` → clotrimazole (82% off).
- **#4 plain-vs-combo → FIXED.** A generic name ("Paracetamol 500 mg") whose brand token IS a
  salt now matches by composition via a salt-lookup that prefers the **plain single-salt** drug
  (median-priced representative), not a combo that merely starts with the same words.
  `Paracetamol 500 mg` → plain paracetamol 500mg (76% savings shown), no longer a caffeine combo.
- Result: benchmark **5/12 matched** (of the 7 misses, 4 are correct safe non-matches —
  generic descriptors/homeopathy/packaging — 2 acceptable, 1 real coverage gap: Doxozest).
  Added regression cases for all four to `code/test_matching.py` → PASS (0 wrong).

## pharm_5 — first REAL (non-sample) receipt (2026-06-25)
Sant Pharmacy, Chandigarh — a rheumatoid-arthritis regimen (12 items). **8/12 matched**, 4
correctly flagged Rx, large savings (Jan Aushadhi anchors on methotrexate/leflunomide/pregabalin).
- ✓ Correctly flagged **[H]**: Folitrax 10/15 (methotrexate), Pregeb (pregabalin), Wysolone (prednisolone).
- ⚠️ **NEW safety gap**: `LEFRA` (leflunomide) and `HCQS` (hydroxychloroquine) matched but show **[OTC]** —
  both are prescription-only DMARDs (leflunomide is teratogenic). The curated schedule list is missing
  DMARDs/specialty salts. **Fix: add leflunomide, hydroxychloroquine, sulfasalazine, azathioprine,
  mycophenolate, tofacitinib, etc. to `_SALTS_H`.** (Same root cause as the remdesivir gap.)
- ✓ Matched well: Eyemist (HPMC eye drops, 54% off), Flexon (ibuprofen+paracetamol, 84% off), HCQS,
  Pregeb, Wysolone — all via fuzzy/salt-lookup on real brand names.
- ✗ Coverage/match misses: **Saridon** (paracetamol+propyphenazone+caffeine combo), **Crocin 650**
  (paracetamol 650 — surprising; investigate), **Shelcal 500** (calcium+vit-D3 combo), **Evion 400**
  (vitamin E). Common brands — likely combo-composition or brand-coverage gaps. Worth a look.
- Takeaway: matching held up on a real, messy photo receipt; the actionable gap is **schedule
  coverage for DMARDs/specialty drugs** (safety) plus a few common-brand matches (recall).

## What worked
- Format-agnostic (webp/jpg/png all handled). Fuzzy match resolved `REMDAC` → remdesivir.
- **Safe-by-default**: homeopathy, saline, generic descriptors, and packaging correctly did
  NOT produce wrong matches — the precision-first design held on genuinely unmatchable items.

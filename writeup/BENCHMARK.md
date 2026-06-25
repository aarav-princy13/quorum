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

## What worked
- Format-agnostic (webp/jpg/png all handled). Fuzzy match resolved `REMDAC` → remdesivir.
- **Safe-by-default**: homeopathy, saline, generic descriptors, and packaging correctly did
  NOT produce wrong matches — the precision-first design held on genuinely unmatchable items.

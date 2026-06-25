# Data Cleaning — Salt/Strength Canonicalization

**Date:** 2026-06-24 · Goal: clean the catalog so same-active products group correctly for substitution — **methodically, evidence-first, and without unsafe merges.**

## Method: analyze before changing anything
We did not assume which variants exist — we measured them on the real ingested catalog
(`code/analyze_salts.py` + ad-hoc queries).

## What the evidence showed (and overturned)
1. **Salt spelling is already consistent.** The dataset uses exactly one spelling per drug:
   `paracetamol` (17,285; never "acetaminophen"), `amoxycillin` (8,375; never "amoxicillin"),
   `furosemide`, `cetirizine`, `cefalexin`, `rifampicin`. → A salt-synonym map is a
   **near-no-op on this single source.**
2. **Pharmacopoeia qualifiers are negligible** — exactly 1 product (`tadalafil ip`).
3. **The real dirt is missing/junk doses:** 3,335 products (1.4%) had no real strength
   (`na`, `na+na`, plus parser artifacts like `na+pyridoxine)(na` exposing a multi-paren
   parsing bug). Recommending a substitute when the **dose is unknown is a safety hazard.**
4. **Different salt forms coexist and must stay separate:** `metoprolol succinate` (645) vs
   `tartrate` (55) — different release profiles, **not interchangeable**.

## Decisions (what we did)
| Action | Rationale | Safety |
|--------|-----------|--------|
| **Salt canonicalizer** (`b2g/normalize.py`): strip pharmacopoeia qualifiers (ip/bp/usp…) + curated cross-spelling synonym map (acetaminophen→paracetamol, albuterol→salbutamol, frusemide→furosemide, …) | No-op now, but folds **future** Jan Aushadhi/NPPA/1mg spellings onto this dataset's canonical form | spelling/INN only |
| **Strength canonicalizer**: lowercase, de-space, `500.0mg`→`500mg`; **no digit ⇒ unknown** | Tightens grouping; isolates junk doses | exact, lossless |
| **`strength_known` flag + exclusion**: unknown-dose products are matched but **never offered as a substitute** | Don't recommend a product whose dose we can't verify | core safety win |
| **Robust multi-paren parser**: salt = text before first `(`, strength = LAST `(...)` | Fixes `Cholecalciferol (Vitamin D3) (1000IU)` → `(cholecalciferol, 1000IU)` | fewer junk rows |
| **Do NOT merge salt forms** (succinate vs tartrate, sodium vs potassium) | Different PK / not interchangeable | deliberate non-merge |

## Measured result
- Distinct compositions: **10,946 → 10,900** (modest, as predicted — data was already clean).
- Unknown-dose products quarantined from recommendations: **3,474**.
- Verified non-merges: metoprolol succinate/tartrate and the mineral citrates stay separate.
- Verified behavior: matching `Adrenaline Tartrate Injection` (unknown dose) offers **no** substitute.

## Honest takeaway
The headline grouping gain is small **because the single open dataset is already consistent** —
the right finding, not a disappointing one. The lasting value is (a) the **unknown-dose safety
guard**, (b) the **robust parser**, and (c) the **cross-source synonym infrastructure** that
earns its keep the moment we add authoritative Jan Aushadhi/NPPA prices.

## Follow-ups
- Grow `_SALT_SYNONYMS` as new sources are merged (that's when it matters).
- Validate curated H1/X salt lists against the official gazette.
- Consider mcg↔mg / %w/v↔mg/ml equivalence (left out: low volume, changes familiar labels).

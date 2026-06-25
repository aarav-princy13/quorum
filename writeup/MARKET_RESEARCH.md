# Market Research & Feasibility

**Date:** 2026-06-24
**Question:** Idea conceived in 2023 — is it still feasible in 2026, and is the space already taken?

## Verdict (short)
**Still feasible.** The market is large and growing, and the *specific combination* the owner wants — **receipt OCR + safety/abuse flagging + a neutral finder for cheaper generics at *nearby physical* pharmacies** — is **not** offered as a single product today. However, **every individual piece exists**, and several well-funded players own adjacent ground. The defensible wedge is the *entry point (the printed receipt)* and *neutrality (not selling our own stock)*. The hardest unsolved problem is **nearby-pharmacy inventory & live pricing data**, which is exactly why incumbents avoided it (they became pharmacies instead).

## Market size (tailwind is real)
- India generic drugs market: **~USD 26–30B in 2025**, projected ~USD 35B by 2030 (~6% CAGR).
- India online pharmacy (ePharmacy): **~USD 3.7B in 2025 → ~USD 14B by 2034** (~16% CAGR) — fastest-growing distribution channel.
- Government tailwind: **PMBJP / Jan Aushadhi** scheme actively pushing affordable generics.

## Competitive landscape
| Player | What it does | How it differs from our idea |
|--------|--------------|------------------------------|
| **Medkart** | "India's first" brand↔generic compare tool; prescription upload; sells own WHO-GMP generics (save up to 85%) | Sells its *own* stock; input is manual search / prescription, **not a receipt**; not a neutral local finder |
| **Truemeds** | Salt-composition substitution algorithm; sells own generics (save up to 51%) | Own-pharmacy model; manual entry |
| **DavaIndia** | Generic pharmacy chain + app; 2000+ generics | It *is* a pharmacy chain; promotes its own stores |
| **Tata 1mg / Netmeds / PharmEasy** | Mainstream e-pharmacies with "find by generic name" features | Generic search is a side-feature; own fulfillment; no receipt scan |
| **Jan Aushadhi Sugam (Govt/PMBI)** | GPS finder for nearby Jan Aushadhi Kendras; compares generic vs brand price; some real-time availability | Closest on "nearby store + price compare," but **govt Kendras only**, manual entry, **no receipt OCR**, no abuse flagging |
| **SayaCare, Medbuzz, MedSub.in, HealthKartPlus, MyDawaai, MedIndia, GenericMeds** | Search/compare generics by brand or salt name | All **manual search**; databases/directories; no receipt scan, no nearby live finder |

**Confirmed gap:** web research found *no* app combining (receipt scan) + (generic alternative) + (locate at nearby pharmacies) in one integrated product. Each capability exists in isolation.

## The "can they even buy it?" / anti-overdose feature — reality check
Maps to India's **Drugs & Cosmetics Act** drug schedules:
- **Schedule H / H1 / X** — prescription-only. **H1** specifically covers higher-misuse/overdose-risk drugs (certain sedatives, opioids-adjacent, key antibiotics). The "Rx" symbol + "Not to be sold without prescription" box are mandated on packaging.
- Reality: a 2021 study found **70–90% of pharmacies sell Schedule H1 without a prescription** — enforcement is weak.

**Implication for design:** We *cannot* build a foolproof legal gate (we can't verify a real prescription, and we don't control the sale). What we **can** do: **classify the scanned drug against the Schedule H/H1/X list and surface a clear warning** ("prescription-only; abuse/overdose risk") and optionally require the user to confirm a prescription before showing purchase options. Frame it as **safety information + friction**, not enforcement.

## Regulatory caveat for the business model
The Drugs & Cosmetics Act has **no clear provision for online sale/home delivery** — ePharmacy is legally grey and periodically challenged. **A neutral *informational* app that scans, advises, and points users to *physical* nearby pharmacies (without itself selling/delivering) sits in a safer regulatory zone** than an online-selling model. This actually favors the owner's stated "show search results for nearby pharmacies" framing.

## Biggest risks / open problems (ranked)
1. **Nearby-pharmacy inventory + live generic pricing data** — no public, complete source. Incumbents solved this by *being* the pharmacy. This is the make-or-break.
2. **Receipt OCR accuracy** — thermal receipts, inconsistent formats, brand names + dosages, smudging.
3. **Mapping branded item → correct generic equivalent** — needs a reliable salt/strength database (e.g., NPPA price data, CDSCO, drug databases).
4. **Regulatory framing** of the safety feature and any purchase facilitation.
5. **Trust** — health advice liability; must include disclaimers / "consult your doctor / pharmacist."

## Sources
- https://www.medkart.in/ — Medkart generic compare & app
- https://theprint.in/ani-press-releases/medkart-launches-indias-first-tool-to-find-substitute-medicine-and-compare-prices-transforming-access-to-affordable-healthcare/2611525/
- https://www.truemeds.in/ — Truemeds salt-based substitution
- https://www.davaindia.com/ — DavaIndia generic pharmacy
- https://www.netmeds.com/page/find-medicines-by-their-generic-name
- https://play.google.com/store/apps/details?id=in.gov.pmbjp — Jan Aushadhi Sugam app
- https://janaushadhi.gov.in/pmjy.aspx — PMBJP scheme
- https://medsub.in/ — MedSub substitute finder
- https://laafon.com/understanding-schedule-h-drugs-regulations-and-restrictions-in-india/ — Schedule H 2026 guide
- https://en.wikipedia.org/wiki/Schedule_H — Schedule H/H1
- https://pmc.ncbi.nlm.nih.gov/articles/PMC8092171/ — non-prescription H1 antibiotic sale study
- https://www.ibanet.org/e-pharmacies-and-the-law-an-uneasy-balance — ePharmacy legality
- https://www.mordorintelligence.com/industry-reports/india-generic-drugs-market — market size
- https://www.imarcgroup.com/india-online-pharmacy-market — ePharmacy market size

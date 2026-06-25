# Product Spec — brand_to_generic (working title)

**Date:** 2026-06-24 · **Phase:** Discovery (pre-build)

## 1. Problem
In India, branded medicines cost 50–85% more than therapeutically-identical generics. Patients rarely know a cheaper equivalent exists or where to buy it nearby. Pharmacies hand out a printed receipt with every purchase — an untapped, structured starting point.

## 2. Core user flow (happy path)
1. User photographs a pharmacy **receipt** (or prescription — TBD).
2. App **OCRs** it → extracts each line item: brand name, salt/composition, strength, quantity, price.
3. App **classifies** each drug against India's drug schedules (H / H1 / X). If prescription-only or abuse/overdose-prone → show a **safety warning** and require confirmation before proceeding.
4. App maps each branded item → its **generic equivalent(s)** (same salt + strength).
5. App shows **cheaper generic options and which nearby pharmacies stock them**, with estimated savings.

## 3. Target user & geography
- Primary: cost-conscious patients & caregivers in Indian cities (owner cited **Chandigarh** as an example dense-pharmacy market).
- MVP geography: **TBD** (single city pilot recommended).

## 4. Differentiators (the wedge)
- **Receipt as the entry point** — no competitor scans the printed bill.
- **Neutral finder** — points to *any* nearby physical pharmacy, not our own stock (also a safer regulatory position).
- **Built-in safety/abuse flagging** — Schedule H/H1/X awareness.

## 5. Feature set
### MVP (must-have)
- Receipt image input + OCR → structured line items.
- Brand → generic mapping via a salt/strength database.
- Schedule H/H1/X classification + warning.
- Savings estimate (brand price vs generic MRP).
- Nearby-pharmacy listing (at minimum: locations of generic-friendly stores; live stock is stretch).

### Later
- Live inventory/price from partnered pharmacies.
- Price history, reminders, order/reserve handoff.
- Multi-language (Hindi + regional).

## 6. Non-goals (for MVP)
- We do **not** sell or deliver medicines ourselves (stay informational → safer regulatory zone).
- We do **not** claim to *authorize* a purchase or replace a doctor/pharmacist. Disclaimers required.
- No diagnosis or dosage advice.

## 7. Hard problems (see MARKET_RESEARCH.md for detail)
1. Nearby-pharmacy inventory & live pricing data source (make-or-break).
2. OCR robustness on thermal/smudged receipts.
3. Accurate brand→generic salt mapping (NPPA / CDSCO / drug DB).
4. Regulatory framing of the safety + purchase-facilitation features.

## 8. Engineering constraints
- Prefer **Python standard library** and lightweight deps. **No pandas.** Justify & get approval before adding heavy libraries.
- Keep code in `code/`, generated artifacts in `output/`, docs in `writeup/`.

## 9. Open decisions (blocking — see SESSION.md "Questions for owner")
- Form factor: native mobile app vs web vs CLI/Python prototype first?
- OCR approach: offline (Tesseract) vs cloud (Google Vision) vs LLM vision?
- Pharmacy data source: Google Places + govt data vs pharmacy partnerships vs crowd-sourced?
- Safety feature strictness: warn-only vs require prescription confirmation?
- Drug/price database source for brand→generic mapping.
- MVP city + monetization model.

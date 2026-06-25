# Session Log

## 2026-06-24 — Session 1: Idea intake, research, repo setup

### What the owner brought
App idea (conceived 2023): in India, pharmacies are dense (e.g., Chandigarh) and issue printed receipts. Many carry generics that are much cheaper than brand-name with the same benefit. Desired app:
1. Scan the **receipt** → OCR it.
2. Confirm the buyer can legally/safely buy the medicine (not illegally purchasing to overdose).
3. Show search results for **nearby pharmacies** carrying cheaper **generic** variants.

Owner's instructions: research feasibility & whether the idea is taken; set up a git repo here; capture discussion as Specs/todos/memories/session in md files; `code/`, `output/`, `writeup/` subdirs; avoid inefficient libraries (no pandas), basic libs only unless justified; then ask for more specifics. **Ask questions, never assume.**

### What I did this session
- Ran web research on competitors, the receipt-OCR niche, drug-schedule regulation, and market size.
- Wrote up findings → `MARKET_RESEARCH.md`. **Verdict: still feasible; the specific combination is an open gap; hardest problem is nearby-pharmacy live data.**
- Initialized git repo + `code/` `output/` `writeup/` dirs.
- Wrote `README.md`, `SPEC.md`, `MARKET_RESEARCH.md`, `TODO.md`, this log.
- Saved durable memories (project + library-preference feedback).

### Key findings (1-liners)
- Market is large & growing (generics ~$26–30B; ePharmacy ~16% CAGR).
- Many competitors do **manual search** or **sell their own generics** (Medkart, Truemeds, DavaIndia, 1mg…). None scan the **receipt** + find generics at **neutral nearby** pharmacies.
- Jan Aushadhi Sugam (govt) is closest: GPS finder + price compare, but Kendras-only, manual entry, no OCR.
- "Anti-overdose / can they buy it" → maps to Schedule H/H1/X. Can't be a real legal gate; design it as **warning + friction**.
- Informational (non-selling) model avoids the D&C Act online-sale grey zone — aligns with the owner's "find nearby pharmacy" framing.

### Naming note
Owner said "write up sub directory"; created it as **`writeup`** (no space) for shell/code friendliness. Say if you want it renamed.

### Decision: git
Ran `git init` and will make an initial commit capturing these docs (setup was explicitly requested). No remote configured.

### Next step
Ask the owner the blocking questions (see below), then scope Phase 1.

### Questions for owner (blocking)
1. Form factor for first build — native mobile app, web app, or a Python prototype of the pipeline first?
2. OCR approach — offline/basic (Tesseract) vs cloud (Google Vision) vs LLM vision? (affects "basic libraries only" constraint)
3. Nearby-pharmacy data — Google Places + govt data (locations only), pharmacy partnerships, or crowd-sourced inventory?
4. Safety feature — warn-only, or require prescription confirmation before showing purchase options?
5. (minor) MVP city, and monetization model (free/info, lead-gen to pharmacies, ads, subscription)?

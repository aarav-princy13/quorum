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

### Questions for owner (blocking) — ANSWERED
1. Form factor → **both iPhone + Android** (cross-platform); likes a **backend/no-UI Python pipeline** but wants to keep evaluating; wants **on-device image processing for privacy**; explore **IBM Docling / recent OCR LLMs**.
2. OCR → **Tesseract rejected** (tried before, weak/inconsistent). Use modern on-device OCR/VLM.
3. Nearby-pharmacy data → **locations-only first**; partnerships later but owner is **not in India / lacks local contacts**.
4. Safety → **Warn + confirm Rx**.

## 2026-06-24 — Session 1 (cont.): Architecture research

### Did
- Re-ran OCR/VLM research framed to surface **newest 2026 models** (owner flagged my memory of model names as stale — verify, don't recall).
- Wrote `ARCHITECTURE.md`: privacy-driven split (on-device OCR; stateless Python backend gets only text), on-device OCR options, framework comparison, phased build, data sources.
- Fixed git author → **Aarav <aarav10a1@gmail.com>**, removed Co-Authored-By trailer (saved as memory).

### Current-model landscape (mid-2026, from web — must benchmark on real receipts)
- **On-device text OCR:** Google **ML Kit Text Recognition v2** (cross-platform, on-device, supports **Devanagari**) = baseline. Apple Vision = iOS-only.
- **On-device small VLMs (structure):** IBM **Granite-Docling-258M** (Jan 2026, Apache-2.0, Apple Silicon/MLX), SmolVLM-256M, MiniCPM-V (~3B, phone-capable), MagicVL-2B (mobile), Phi-4-multimodal, Pixtral.
- **Cloud-only (higher acc., breaks privacy):** dots.ocr, Qwen3-VL, GLM-4.5V, DeepSeek-VL2, Nemotron-3-Nano-Omni — opt-in fallback at most.
- **Leaning:** Flutter app + ML Kit baseline, benchmark Granite-Docling/small-VLM on real receipts. Decide OCR engine empirically.

### Next open decisions (asking owner now)
1. App framework — Flutter / React Native / native.
2. Privacy boundary — may drug *text* reach the backend, or fully on-device (bundle DB+maps)?
3. On-device OCR engine — ML-Kit-text-first vs small-VLM-first vs benchmark bake-off.
4. Drug/price data — assemble public NPPA/Jan-Aushadhi/CDSCO ourselves vs license a DB.

### Round-2 answers (owner)
1. Framework → **Flutter** (eventual app) — but **start with the Python backend first** ("so I understand the code first", no Flutter experience).
2. Privacy → **image on-device, text to backend**.
3. OCR engine → **benchmark bake-off first** on real receipts.
4. Drug data → owner deferred to me → researched & wrote `DATA_SOURCES.md` (assemble open composition dataset + Jan Aushadhi + NPPA into SQLite; verify licensing before commercial).

### Did (backend scaffold)
- Wrote `DATA_SOURCES.md` (recommendation: 3-layer SQLite assembly, stdlib only).
- Built a **runnable stdlib Python backend** under `code/`: `schema.sql`, seed CSVs, package `b2g/` (db, schedule, matcher, pipeline), `demo.py`.
- `python3 code/demo.py` runs the full flow on a simulated OCR'd Chandigarh receipt → generic matches, savings, H/H1/X warnings + Rx-confirm flags, nearby pharmacies. Sample total savings **₹302.24**; writes `output/demo_result.json` + `demo_report.txt`. Verified working.

### Next (proposed)
- Ingest **real** Jan Aushadhi / NPPA / open-composition data into SQLite (replace tiny seed).
- Harden brand-name matching (fuzzy) for real OCR text.
- Plan the OCR benchmark (collect real receipts).
- Later: stdlib `http.server` API layer, then the Flutter app.

## 2026-06-24 — Session 1 (cont. 2): Real data ingested

Owner chose **"ingest real drug data"**.
- Probed network (curl works). Found & downloaded the open **Indian Medicine Dataset**
  (`junioralive/Indian-Medicine-Dataset`, ~254k rows: name, price, manufacturer, pack, composition).
- Wrote `code/ingest.py` (stdlib): parse composition → salt+strength, classify schedule from
  salt, normalize pack→units & unit_price, skip discontinued. Built `data/b2g.db`:
  **246,068 products, 10,946 compositions, 139,316 schedule-flagged.**
- Added `code/query.py` (query real DB), `b2g/util.py`, `b2g/report.py` (shared renderer).
- **Caught & fixed 2 correctness bugs** that would mislead users:
  1. tablet was being substituted by an **injection** → now matches **same form** only.
  2. **pack-size mismatch** inflated savings (per-strip vs per-tablet) → now **per-unit pricing**.
  - Plus an **outlier floor** (drop prices < 20% of composition median = data-entry errors).
- Verified: sample real receipt → plausible generics, ~₹430 savings, correct H/H1/X flags
  (paracetamol/cetirizine OTC; alprazolam/tramadol H1; methylphenidate X). Artifacts in `output/`.
- `data/` (raw CSV + 60 MB DB) is gitignored; only code is committed.

### Open data caveats (documented in DATA_SOURCES.md)
- Open dataset has price outliers, salt-spelling variants, unspecified license → prototype only.
- Authoritative Jan Aushadhi/NPPA prices still to be added.

## 2026-06-24 — Session 1 (cont. 3): Data cleaning (salt/strength canonicalization)

Owner chose **#2 (salt-synonym normalizer)** — "clean up our dataset, methodically, nothing unfinished."
- **Analyzed first** (`code/analyze_salts.py` + queries) instead of assuming. Empirical finding
  **overturned the premise**: the dataset is already salt-consistent (one spelling per drug;
  pharmacopoeia qualifiers = 1 product). A synonym map is a near-no-op on this single source.
- **Real dirt found:** 1.4% of products had missing/junk doses (`na`, parser artifacts) — and a
  multi-paren composition-parsing bug.
- **Built `b2g/normalize.py`** (canonical salt + strength), a **robust multi-paren parser**, and a
  **`strength_known` guard** that excludes unknown-dose products from being recommended (safety).
- **Deliberately did NOT merge salt forms** (metoprolol succinate vs tartrate) — verified they stay separate.
- Verified: unit tests on the normalizer pass; matching an unknown-dose product offers no substitute;
  distinct compositions 10,946 → 10,900; 3,474 products quarantined. Full record in **DATA_CLEANING.md**.
- Honest takeaway: small grouping gain (data was clean); lasting value = safety guard + robust parser +
  cross-source synonym infra for when Jan Aushadhi/NPPA are added.

## 2026-06-25 — Session 1 (cont. 4): Authoritative Jan Aushadhi prices

Owner: "continue" with authoritative prices (Jan Aushadhi + NPPA).
- **Investigated sources first** (the methodical pattern). NPPA & Jan Aushadhi are PDF/portal-locked;
  no CSV/JSON mirrors. But found the Jan Aushadhi site is a React SPA with a **public JSON API on
  port 8443** (discovered the host via the page's CSP `connect-src`; payload shape read from the JS
  bundle). Endpoint: `POST /api/v1/admin/product/getAllProductForWeb`.
- **Built `code/ingest_janaushadhi.py`** (stdlib json/sqlite/re): fetch → parse free-text `genericName`
  into (salt, strength, form) with **positional salt↔dose pairing** (handles both combo layouts),
  skip unpriced rows → insert as `is_authoritative=1, is_generic=1, source='janaushadhi'`.
  Result: **2,052 priced products, ~950 match brand comps, 1,572 anchors.**
- **Cross-source fixes:** added PK-neutral salt-form folding (hydrochloride only — metformin
  hydrochloride→metformin; succinate/tartrate still separate, verified). Added `is_authoritative`.
- **Matcher upgrades:** authoritative prices **exempt from the outlier floor** (govt prices are
  genuinely low); report shows a **✓Jan Aushadhi (govt)** anchor. Fixed a bug where the anchor was
  computed over the truncated top-25 (now over the full candidate list — Azithral now shows the
  official ₹13.13/unit alongside the cheapest market option).
- **NPPA:** server-rendered CMS + gazette PDFs + ASP.NET portal → not cleanly stdlib-ingestable.
  Documented options (data.gov.in key / PDF dep / curated subset); **deferred**. Jan Aushadhi already
  covers the generic-price layer.
- Verified: seed regression, safety rechecks, realistic receipt (Telma/Pan anchor at ~₹1.2/unit).

## 2026-06-25 — Session 1 (cont. 5): Real pharmacy locations

Owner: skip NPPA; next = real pharmacy locations (my recommendation too — it's the make-or-break
feature, still on fake seed data, and pairs with the JA prices).
- Tried the Jan Aushadhi Kendra endpoints (`getNearByKendra`, `getAllKendra`) — **500'd** on every
  guessed payload (undocumented). Methodical call: don't fight a flaky endpoint when a robust,
  documented, **neutral** source exists.
- Pivoted to **OpenStreetMap Overpass API** (neutral = any pharmacy, the app's actual wedge).
  Quirk: needs a **User-Agent** header or it returns 406.
- Built `code/ingest_pharmacies.py` (stdlib urllib, retries, JSON-validated): fetch pharmacy nodes
  near a lat/lon → store real locations in the `pharmacies` table (replaces seed). Added
  `haversine_km` (b2g/util.py) and rewrote `nearby_pharmacies()` to rank by real distance.
- Result: **15 real tricity pharmacies**, distance-ranked (Verma Medical Hall 1.36 km → Panchkula
  12.6 km). Report shows distance + ✓ marker for Jan Aushadhi Kendras.
- Honest caveat: **OSM pharmacy coverage in India is sparse**; production needs Google Places or the
  Jan Aushadhi Kendra directory. Now every layer (catalog, official prices, locations) is REAL data.

## 2026-06-25 — Session 1 (cont. 6): Fuzzy name matching (precision-first)

Owner: do fuzzy name matching next.
- **Analyzed failures first**: current exact/prefix got 5/10 on receipt-style names. Failure modes:
  extra tokens (`Glycomet 500 SR Tablet`), `500` vs `500mg`, abbreviations (`Tab`), no-space (`Telma40`).
- Built a conservative **stdlib `difflib`** fuzzy fallback in `_lookup_drug` (blocks on brand prefix,
  scores by string ratio + token Jaccard). `_lookup_drug` now returns `(row, match_type)`.
- **Safety bar = precision over recall** (wrong drug worse than a miss). Two guards:
  - letter↔digit split in `normalize` (`telma40`→`telma 40`, `500mg`→`500 mg`) — also helps exact/prefix.
  - **discriminator guard**: every distinguishing token (numbers, single letters, `b12`/`d3`) must be in
    the candidate. **Caught a dangerous false positive** in testing: `Vitamin C`→`Vitamin A` (0.63);
    the guard now forces `Vitamin C`→a Vitamin-C product, and `Glycomet 500`↛ combo `Glycomet-GP`.
- Report flags fuzzy hits as `≈ approx match: <name>` for user verification.
- Added regression suite `code/test_matching.py` (asserts composition + safety) → **PASS, 0 wrong**.
  10/10 functional + safety negatives; the one deliberate miss is an OCR brand typo (`Crocln`) = safe.

## 2026-06-25 — Session 1 (cont. 7): Secure HTTPS API

Owner: build the API; **maximum security** — rate-limited + "hidden" + asked for more ideas.
Decisions (asked): **API key + HMAC signing**, **HTTPS in the server now**, **rate-limit per key + IP**.
- Planned it (writeup/API_DESIGN.md), flagged honestly that stdlib `http.server` still needs a
  reverse proxy in production.
- Built (stdlib only): `b2g/security.py` (HMAC verify + token-bucket limiter + nonce cache),
  `code/server.py` (HTTPS handler: concurrency cap → IP rate limit → read+cap body → HMAC auth →
  key rate limit → strict validation → read-only pipeline), `gen_secrets.py`, `client_example.py`.
- Security measures (beyond rate-limit + auth): TLS≥1.2, **per-request nonce** (replay/tamper +
  no false-dup rejections), ±300s timestamp window, no-content logging (no drug names),
  read-only DB (`mode=ro`), 16KB/50-item caps, constant-time compare, generic errors, hidden
  banner, security headers, bounded concurrency.
- **Verified live**: valid signed → 200; no-auth/bad-sig/expired/replay → 401; unknown → 404;
  oversized → 400; flood → burst then 429 (per key+IP). Found & fixed a false-replay edge
  (identical payload same second) by adding the nonce.
- Secrets (`secrets/`, keys 0600) and `*.pem` are gitignored — only code committed.

## 2026-06-25 — Session 1 (cont. 8): First real-receipt benchmark

Owner shared 4 real receipts (pharm_1..4, mixed webp/jpg/png) to try.
- Read each via vision (= VLM-OCR path); several were low-res → crop+upscale with ImageMagick.
  Extracted line items → fixtures `code/ocr_samples/*.json`. Built `code/ocr_bench.py`.
- Diverse set: brand injectables (Remdac/Mepem/Doxozest), generic descriptors (Paracetamol 500/
  Cough Syrup/Antibiotic Cream), homeopathy (Belladonna 30), non-drug (saline, plastic), topicals.
- Result: 12 items, 2 matched, 10 not found — but ~5 are CORRECT safe non-matches (homeopathy,
  saline, generic descriptors, packaging). The precision-first design held (no wrong matches on
  unmatchable items).
- **Found real, fixable gaps** (writeup/BENCHMARK.md): (1) unit-blind discriminator `1gm`≠`1000mg`
  missed meropenem-H1 [in catalog]; (2) pack-size tokens `5GM`/`75GM` wrongly required → missed
  Mupikem/Clocip [in catalog]; (3) schedule list misses injectables → remdesivir shown OTC
  (safety); (4) plain `Paracetamol 500` matched a caffeine combo (precision); (5) Doxozest absent
  (coverage). Receipt images gitignored (pharm_*); fixtures committed.

## 2026-06-25 — Session 1 (cont. 9): Fix the safety pair (#1 + #3)

Owner: fix the safety pair.
- **#1 unit-blind discriminator** → made strength matching **unit-aware** (`_strength_sigs`:
  number+unit → mg-equiv, 1gm=1000mg=bare-1000; ml/iu kept separate). Replaced the raw-token
  discriminator guard. Then MEPEM passed the guard but failed the score threshold (only "mepem"
  overlapped) → measured the components and added a **brand-token bonus** (`score = 0.6·ratio +
  0.4·jacc + 0.3·brand_jacc`). `MEPEM 1GM INJ` → meropenem 1000mg **H1**. REMDAC (brand≠catalog
  "Remdiz") still matches via ratio — verified both with measured scores, not guesses.
- **#3 schedule misses injectables** → expanded curated salts (remdesivir/favipiravir/cytotoxics/
  injectable antibiotics/anticoagulants) and added **`schedule_for(salt, form)`** with a parenteral
  fallback (unknown injection/infusion → H). Wired into both ingesters (re-ingest). REMDAC→
  remdesivir now **H**; oral OTC (paracetamol tablet, cetirizine, vitamin C) stays OTC — verified.
- Result: benchmark matched 2→3, Rx-flagged 0→2, savings up (meropenem 82% off); `test_matching.py`
  PASS (0 wrong). Remaining benchmark gaps: #2 pack-size, #4 plain-vs-combo.

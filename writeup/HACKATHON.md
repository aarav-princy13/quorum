# Hackathon layer — Gemma 4 on Cerebras

**Event:** Cerebras x Google DeepMind Gemma 4 (24h). **Model:** `gemma-4-31b` (OpenAI-compatible,
text+image, structured outputs, ~1450 tok/s). **Tracks:** 1 — Multi-Agent + Multimodal ($2K, primary);
3 — Enterprise ($1K, secondary).

This doc covers ONLY the new Gemma-on-Cerebras layer added for the hackathon. The rest of the product
(receipt → OCR → brand→generic + savings + Schedule safety + nearby pharmacies) is unchanged; see
`session_transfer.md`.

## What we add (built during the 24h)
1. **Opt-in Cerebras VLM OCR** — Gemma 4 *vision* reads the receipt image in one pass → line items.
   This is the *multimodal* ingredient + the Cerebras *speed* showcase. **On-device OCR stays the privacy
   default;** the cloud path is explicit opt-in ("high-accuracy / low-end device"). (Build: after the quorum.)
2. **Safety Quorum** — a multi-agent verification committee on top of the deterministic matcher.

## Conventions (inherited — do not violate)
- Backend **stdlib only, no pandas/heavy deps** → Cerebras is called over stdlib `urllib` (no SDK).
- **Privacy:** image on-device by default; cloud only on opt-in.
- **Precision over recall:** a wrong drug is worse than a miss.
- Git author `Aarav <aarav10a1@gmail.com>`, **no Co-Authored-By**.

## Safety Quorum — design (LOCKED 2026-06-28)
The matcher already guarantees cheaper alternatives share **same salt + strength + form** (equivalent by
construction). So the quorum does NOT re-pick drugs. Its two jobs:
1. **Match-verify** — especially non-`exact` matches (`prefix`/`alias`/`fuzzy` are guesses): does the OCR'd
   name plausibly mean this salt+strength?
2. **Safety-flag** — clinical switch-cautions the DB can't model: narrow-therapeutic-index (NTI) drugs,
   modified-release/salt-form interchange.

### Core principle — one-way ratchet
**The quorum can only ADD caution, never override the DB.** It cannot upgrade an unsafe match to safe,
invent a drug, or change a price. It only lowers confidence / adds flags / says "verify with pharmacist".
→ A hallucinated *caution* is a safe failure (user double-checks). DB stays source of truth.

### Risk gate (which items run the committee)
Run the committee on an item iff: `match_type != exact` **OR** Rx-flagged (Schedule H/H1/X) **OR** salt is NTI.
Exact OTC same-salt swaps **auto-pass** (saves rate-limit, focuses compute where it matters).

### Committee (4 method-diverse lenses, parallel Gemma calls)
- **identity** — is the brand→salt+strength identification correct?
- **formulation** — form/route, modified-release, salt-form interchangeability.
- **clinical** — NTI? special-population caution? doctor-supervised switch?
- **skeptic / red-team** — argue why the match/switch could be wrong; default to caution.

Each lens returns `{verdict: ok|caution|reject, confidence, flags[], note}`.
**Aggregation is DETERMINISTIC** (no LLM moderator → no extra hallucination surface): final verdict = the
most cautious lens; flags = union; confidence pulled down by dissent. Patient-facing explanation is templated.

### Output (attached to each item as `quorum`, DB data untouched)
`{verdict, confidence, label, flags[], explanation, verified: true|auto_pass, timing}`
- `ok` + high → "Safe to switch"  ·  `caution` → "Switch with caution — <reason>"  ·  `reject` → "Couldn't
  verify — ask your pharmacist".

### Speed story
4 parallel Gemma calls per risky item; a whole bill verifies in seconds at ~1450 tok/s — impractical on slow
inference. Surface per-call timing; (stretch) side-by-side vs a GPU provider.

## Build order
1. [DONE] `code/b2g/cerebras.py` — stdlib urllib client (text+image, structured outputs, reasoning, timing).
2. [DONE] `code/b2g/quorum.py` — lenses, NTI list, risk gate, parallel fan-out (threads), ratchet merge + mock.
3. [DONE] `code/quorum_demo.py` — matcher → quorum → report (auto live/mock). Mock verified on the real 248k DB.
4. [DONE] Live-verified the quorum on real Gemma (verdicts strong — see status).
5. [DONE] Opt-in Cerebras VLM OCR (`code/b2g/vlm_ocr.py`) + end-to-end `code/scan_demo.py` (image→OCR→matcher→quorum).
6. [NEXT] Live-verify VLM OCR on a real image (pharm_5); then wire into `server.py` + Flutter; record 60s demo.

## Status (2026-06-28)
**Quorum LIVE-VERIFIED.** Real `gemma-4-31b` results: warfarin → caution (clinical lens cited INR monitoring);
**Glycomet 500 → REJECT** (committee caught the IR→SR fuzzy-match: "not therapeutically interchangeable");
exact Rx matches (HCQS/Pan/Telma) → "safe to switch" + Rx reminder. **Speed: 4 agents ~0.5s parallel vs ~1.7s
sequential ≈ 3.4–3.6×.** End-to-end scan demo runs on pharm_5 (real RA bill) in mock; EYEMIST exercises the
exact-OTC AUTO-PASS path; FOLITRAX 10MG exposed a prefix tablet→injection route mismatch to watch for live.
Commits: quorum `c7ac6d1`, UA fix `bf7b594`, VLM OCR + scan demo `99e0b16`. Existing suites green.
**Next action:** run `python3 code/scan_demo.py pharm_5` LIVE (real Gemma vision OCR + quorum).

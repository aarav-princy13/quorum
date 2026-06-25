# brand_to_generic

A mobile/app concept for India: **scan a pharmacy receipt → OCR it → flag any restricted/abuse-prone drugs → find cheaper *generic* equivalents at nearby pharmacies.**

The core insight: branded medicines in India often cost 50–85% more than therapeutically-identical generics (same salt, same strength). Most people never check. This app closes that gap starting from the one artifact every pharmacy hands you — the printed bill.

## Status
Discovery / planning phase (started 2026-06-24). No application code yet — pending tech-stack and data-source decisions from the owner. See [writeup/](writeup/).

## Repository layout
| Dir | Purpose |
|-----|---------|
| `code/`    | Application + prototype source code |
| `output/`  | Generated artifacts (OCR results, sample runs, exports) |
| `writeup/` | Specs, research, todos, session notes (the "thinking") |

## Key documents
- [writeup/SPEC.md](writeup/SPEC.md) — product spec & scope
- [writeup/MARKET_RESEARCH.md](writeup/MARKET_RESEARCH.md) — feasibility & competitor analysis
- [writeup/TODO.md](writeup/TODO.md) — phased task list
- [writeup/SESSION.md](writeup/SESSION.md) — running session log

## Engineering constraints
- Prefer the **standard library**; avoid heavy/inefficient dependencies (explicitly **no pandas**) unless a need is justified and approved.

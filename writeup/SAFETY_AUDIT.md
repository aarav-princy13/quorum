# SAFETY_AUDIT.md — Schedule H / H1 / X salt-list reconciliation

**Date:** 2026-06-27 · Reconciles the curated salt lists in `code/b2g/schedule.py`
against India's official drug schedules. Locked by `python3 code/test_safety.py`.

## Why
The open medicine dataset has no schedule column, so we derive H/H1/X from the
active salt(s). The safety flags ("prescription-only", "higher-risk", "controlled")
are a core promise of the app — a wrong flag erodes trust, a missing flag is a
safety gap. This pass replaces a from-memory approximation with the gazette lists.

## Sources
- **Schedule X** (16 substances): Drugs and Cosmetics Rules, Schedule X.
  Cross-checked [Wikipedia: Schedule X](https://en.wikipedia.org/wiki/Schedule_X)
  and [laafon.com Schedule X list](https://laafon.com/schedule-x-drugs-list/).
- **Schedule H1** (46 drugs, 2013 notification; + later additions oxytocin,
  tapentadol): [pharmafranchisehelp H1 list](https://pharmafranchisehelp.com/list-of-schedule-h1-drugs-medicines-molecules/),
  context from [medindia](https://www.medindia.net/health/drugs/drugs-and-cosmetics-rules-schedule-h-schedule-h1-drugs.htm).
- **Schedule H** is several hundred drugs — NOT enumerated here; our `_SALTS_H`
  stays a non-exhaustive curated set of common ones. Authoritative text:
  [CDSCO Drugs and Cosmetics Act & Rules (PDF)](https://cdsco.gov.in/opencms/export/sites/CDSCO_WEB/Pdf-documents/acts_rules/2016DrugsandCosmeticsAct1940Rules1945.pdf).

## Matching model (intentional)
Classification is **substring** match of a salt token within the drug's salt
string (`schedule_for_salts`). This is deliberate: spelling variants and
enantiomer / prodrug / derivative names inherit the parent's schedule. Measured
over the catalog, this correctly keeps **1170 rows** flagged that whole-word
matching would wrongly drop to OTC — e.g. `levosalbutamol`→salbutamol,
`valganciclovir`→ganciclovir, `dexrabeprazole`→rabeprazole, `eszopiclone`→zopiclone.
The one harmful collision it implies — `barbital` ⊂ `phenobarbital` (Schedule H,
not X) — is avoided by **not** listing a bare `barbital`/`barbitone` token; the
specific Schedule X barbiturates are spelled in full instead.

## Changes made (vs the pre-audit lists)

### Fixed under-flags (were OTC / too low → safety gaps)
| salt | was | now | rows | note |
|---|---|---|---|---|
| phenobarbitone / phenobarbital | OTC | H | 69 | barbiturate anticonvulsant; British spelling evaded the list |
| phenytoin | OTC | H | 98 | anticonvulsant, Rx |
| clofazimine | OTC | H1 | 11 | official H1 (leprosy) |
| oxytocin | OTC | H1 | 26 | official H1 (2018 amendment) |
| tapentadol | OTC | H1 | 152 | official H1 (2018), opioid — abuse-prone |
| levofloxacin | H | H1 | 2202 | official H1 (was matched only as a fluoroquinolone H) |

### Fixed over-flags (were H1 but are Schedule H → accuracy)
| salt | was | now | rows | note |
|---|---|---|---|---|
| cefuroxime | H1 | H | 3246 | 2nd-gen cephalosporin; official H1 starts at 3rd-gen |
| sulbactam | H1 | H | 10 | beta-lactamase inhibitor, not separately H1 |
| tigecycline | H1 | H | 80 | restricted IV antibiotic, but Schedule H not H1 |

### Schedule X completeness
Added official X members missing before (rare in this catalog today, kept for
future data): cyclobarbital/cyclobarbitone, ethchlorvynol, meprobamate,
methylphenobarbital/-barbitone, phenmetrazine, phencyclidine, plus -barbitone
spellings of the existing barbiturates. Live X rows unchanged (53: ketamine 30,
methylphenidate 23).

## Deliberate overrides (documented, not bugs)
- **Conservative H1** for `clonazepam`, `lorazepam`, `zopiclone` (and
  `eszopiclone` via substring): officially Schedule H, but habit-forming, so we
  flag them at the higher H1 tier. Safety over strict gazette fidelity.
- **`methaqualone` kept at X**: banned / NDPS in India rather than literally on
  Schedule X — strictest handling is the safe call.
- **Bare `barbital`/`barbitone` omitted** from X (obsolete drug; substring would
  mis-flag phenobarbital). The specific X barbiturates are listed in full.

## Net effect on the catalog
`recompute_schedule.py`: 6000 rows reclassified. OTC 89525→89203 (−322, gaps
closed), H 122364→123610, H1 36178→35254 (cefuroxime out, levofloxacin in), X 53.

## Still open / limitations
- `_SALTS_H` is not exhaustive — many genuine Schedule H drugs absent from the
  catalog's common salts aren't listed; additions are demand-driven.
- Schedule X members not present in the current dataset are listed but untested
  against real rows.
- After editing `b2g/schedule.py`, re-run `python3 code/recompute_schedule.py`
  (no API restart needed — the schedule is read from the DB column per request).

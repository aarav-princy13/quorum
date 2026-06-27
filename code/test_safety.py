#!/usr/bin/env python3
"""Regression tests for Schedule H/H1/X classification (safety flags).

Pins the 2026-06-27 gazette reconciliation (see writeup/SAFETY_AUDIT.md): the
official Schedule X / H1 memberships, our deliberate conservative overrides, the
fixed under-flags, and the substring-collision guard (phenobarbital must NOT be X).

Run:  python3 code/test_safety.py   (no DB needed — pure salt logic)
Exits non-zero on any regression.
"""

import sys
from pathlib import Path

CODE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(CODE_DIR))

from b2g.schedule import schedule_for_salts, schedule_for  # noqa: E402

# (salt, expected_code, why)
CASES = [
    # Schedule X (official)
    ("ketamine", "X", "official X"),
    ("methylphenidate", "X", "official X"),
    ("cyclobarbitone", "X", "official X (British spelling)"),
    ("amitriptyline+ketamine", "X", "strictest component wins"),
    ("methaqualone", "X", "conservative: banned/NDPS -> strictest"),
    # Schedule X false-positive guard: a barbiturate that is actually Schedule H
    ("phenobarbitone", "H", "anticonvulsant: H, must NOT be mis-flagged X"),
    ("phenobarbital", "H", "anticonvulsant: H, must NOT be mis-flagged X"),
    ("phenytoin", "H", "anticonvulsant: H (was a gap -> OTC)"),
    # Schedule H1 (official) — including the gaps we fixed
    ("levofloxacin", "H1", "official H1 (was mis-classed H)"),
    ("clofazimine", "H1", "official H1 (was a gap -> OTC)"),
    ("oxytocin", "H1", "official H1 amendment (was a gap -> OTC)"),
    ("tapentadol", "H1", "official H1 amendment, opioid (was a gap -> OTC)"),
    ("ceftriaxone", "H1", "official H1"),
    ("meropenem", "H1", "official H1"),
    # Conservative H1 (officially H, flagged higher for abuse risk)
    ("clonazepam", "H1", "conservative override"),
    ("lorazepam", "H1", "conservative override"),
    ("eszopiclone", "H1", "conservative via zopiclone substring"),
    # Over-flags we corrected back to Schedule H
    ("cefuroxime", "H", "2nd-gen cephalosporin: H, not H1"),
    ("sulbactam", "H", "beta-lactamase inhibitor: H, not H1"),
    ("tigecycline", "H", "restricted IV antibiotic: H, not H1"),
    # Substring derivative coverage must be preserved (not regressed to OTC)
    ("levosalbutamol", "H", "enantiomer of salbutamol -> H"),
    ("valganciclovir", "H", "prodrug of ganciclovir -> H"),
    # No false alarms
    ("paracetamol", "", "OTC"),
    ("cetirizine", "", "OTC"),
]


def main():
    fails = []
    for salt, expected, why in CASES:
        got = schedule_for_salts(salt)
        ok = got == expected
        print(f"  {'ok' if ok else 'FAIL'}   {got or 'OTC':4} {salt:28} ({why})")
        if not ok:
            fails.append(f"{salt}: expected {expected or 'OTC'}, got {got or 'OTC'}")

    # Parenteral fallback: an unknown injectable salt is still flagged H.
    if schedule_for("totally-unknown-salt", "injection") != "H":
        fails.append("injectable fallback should be H")
    print(f"  {'ok' if not any('injectable' in f for f in fails) else 'FAIL'}   "
          "H    <unknown> injection (parenteral fallback)")

    print(f"\n{'PASS' if not fails else 'FAIL'}: {len(fails)} failure(s)")
    for f in fails:
        print("   -", f)
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())

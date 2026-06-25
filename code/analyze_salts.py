#!/usr/bin/env python3
"""Surface candidate salt-name variants from the ingested catalog (review tool).

Clusters distinct salt components by an AGGRESSIVE fingerprint (spelling +
salt-form-insensitive) purely to *surface* candidate synonym groups for human
review. It does NOT decide merges — see b2g/salt_synonyms.py for the curated,
safe map actually applied at ingest.

Run after ingest:  python3 code/analyze_salts.py
Writes output/salt_variant_candidates.txt
"""

import collections
import re
import sqlite3
import sys
from pathlib import Path

CODE_DIR = Path(__file__).resolve().parent
DB_PATH = CODE_DIR.parent / "data" / "b2g.db"
OUT = CODE_DIR.parent / "output" / "salt_variant_candidates.txt"

# Salt-form / qualifier words dropped ONLY for clustering (not for the real map).
_DROP = {
    "hydrochloride", "hcl", "sodium", "potassium", "sulphate", "sulfate",
    "phosphate", "maleate", "besylate", "dihydrate", "hydrate", "calcium",
    "magnesium", "acetate", "succinate", "tartrate", "fumarate", "mesylate",
    "citrate", "base", "anhydrous", "monohydrate", "trihydrate", "oxide",
    "as", "bp", "ip", "usp", "hemihydrate", "hydrobromide", "hydrobromide",
}


def fingerprint(s):
    s = re.sub(r"[^a-z ]", " ", s.lower())
    words = [w for w in s.split() if w not in _DROP]
    s = "".join(words)
    # spelling folds that commonly differ in Indian listings
    s = s.replace("ph", "f").replace("ae", "e").replace("oe", "e")
    s = s.replace("y", "i").replace("cc", "c").replace("ll", "l")
    return s


def main():
    if not DB_PATH.exists():
        sys.exit(f"DB not found: {DB_PATH} (run ingest first)")
    con = sqlite3.connect(DB_PATH)

    counts = collections.Counter()
    for (salt,) in con.execute("SELECT salt FROM drugs"):
        for c in (salt or "").split("+"):
            c = c.strip()
            if c:
                counts[c] += 1

    clusters = collections.defaultdict(set)
    for name in counts:
        clusters[fingerprint(name)].add(name)
    multi = {k: v for k, v in clusters.items() if len(v) > 1}

    # rank clusters by total occurrences of their members
    ranked = sorted(multi.items(), key=lambda kv: -sum(counts[n] for n in kv[1]))

    lines = [
        f"distinct salt components: {len(counts)}",
        f"candidate variant clusters (>1 spelling): {len(multi)}",
        "",
        "Top candidate clusters (member [count]) — REVIEW before merging:",
        "(⚠ same base + different salt form e.g. succinate/tartrate are NOT interchangeable)",
        "",
    ]
    for _fp, members in ranked[:60]:
        parts = sorted(members, key=lambda n: -counts[n])
        lines.append("  " + "  |  ".join(f"{n} [{counts[n]}]" for n in parts))

    OUT.parent.mkdir(exist_ok=True)
    OUT.write_text("\n".join(lines), encoding="utf-8")
    print("\n".join(lines[:48]))
    print(f"\n[wrote {OUT}]")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Signed test client for POST /v1/scan — the opt-in CLOUD OCR path.

Uploads a receipt image (base64) to the server, which reads it with Gemma 4 vision,
matches generics, and runs the Safety Quorum. Mirrors what the Flutter cloud-scan
toggle will do. Same HMAC scheme as client_example.py.

  python3 code/scan_client.py                 # defaults to pharm_5.jpeg
  python3 code/scan_client.py pharm_1.webp

Server must run WITH CEREBRAS_API_KEY set. Stdlib only.
"""

import base64
import json
import os
import secrets
import ssl
import sys
import time
import urllib.request
from pathlib import Path

CODE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(CODE_DIR))
ROOT = CODE_DIR.parent

from b2g.security import sign  # noqa: E402

BASE = os.environ.get("B2G_BASE", "https://127.0.0.1:8443")
PATH = "/v1/scan"
KEYS_FILE = os.environ.get("B2G_KEYS", str(ROOT / "secrets" / "keys.json"))
_MIME = {".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".png": "image/png", ".webp": "image/webp"}


def main():
    arg = sys.argv[1] if len(sys.argv) > 1 else "pharm_5.jpeg"
    img_path = Path(arg) if Path(arg).exists() else (ROOT / arg)
    if not img_path.exists():
        sys.exit(f"image not found: {arg}")

    data = json.load(open(KEYS_FILE, encoding="utf-8"))
    keyid, secret = next(iter(data.items()))
    secret = bytes.fromhex(secret)

    payload = {
        "image": base64.b64encode(img_path.read_bytes()).decode("ascii"),
        "mime": _MIME.get(img_path.suffix.lower(), "image/jpeg"),
        "location": {"lat": 30.7411, "lon": 76.7820},
        "verify": True,
    }
    body = json.dumps(payload).encode("utf-8")
    ts, nonce = int(time.time()), secrets.token_hex(8)
    signature = sign(secret, "POST", PATH, ts, nonce, body)

    req = urllib.request.Request(BASE + PATH, data=body, method="POST", headers={
        "Content-Type": "application/json", "X-Api-Key": keyid,
        "X-Timestamp": str(ts), "X-Nonce": nonce, "X-Signature": signature,
    })
    print(f"uploading {img_path.name} ({len(body) // 1024} KB) to {BASE}{PATH} …")
    ctx = ssl._create_unverified_context()              # dev self-signed cert only
    with urllib.request.urlopen(req, context=ctx, timeout=60) as resp:
        out = json.load(resp)

    ocr = out.get("ocr", {})
    s = out["result"]["summary"]
    print(f"HTTP 200 · Gemma OCR read {ocr.get('n_items')} items in {ocr.get('latency_s')}s · "
          f"{s['n_found']}/{s['n_items']} matched · total savings ₹{s['total_savings_inr']}")
    for it in out["result"]["items"]:
        if not it["found"]:
            print(f"  • {it['query']}: not found"); continue
        ch = it.get("cheapest_alternative")
        line = f"  • {it['query']}: {it['matched']['salt']} {it['matched']['strength']}"
        if ch:
            line += f" -> ₹{ch['unit_price']:.2f}/unit"
        print(line)
        q = it.get("quorum")
        if q:
            flags = (" [" + ", ".join(q["flags"]) + "]") if q.get("flags") else ""
            print(f"      quorum: {q['label']} ({q.get('overall_confidence')}%, {q['verdict']}){flags}")


if __name__ == "__main__":
    main()

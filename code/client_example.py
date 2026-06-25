#!/usr/bin/env python3
"""Reference signed client for the API — also the blueprint for the Flutter client.

Signs the request with HMAC-SHA256 over "METHOD\\npath\\ntimestamp\\nsha256(body)"
and sends X-Api-Key / X-Timestamp / X-Signature. For dev it reads the shared secret
from secrets/keys.json; a real app embeds its own per-install key.

  python3 code/client_example.py                       # sample receipt
  python3 code/client_example.py "Telma 40" "Pan 40 Tablet"

Stdlib only (urllib, ssl, json). NOTE: TLS verification is disabled here because the
dev cert is self-signed — a production client MUST verify the real certificate.
"""

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

URL = os.environ.get("B2G_URL", "https://127.0.0.1:8443/v1/analyze")
PATH = "/v1/analyze"
KEYS_FILE = os.environ.get("B2G_KEYS", str(ROOT / "secrets" / "keys.json"))

SAMPLE = ["Telma 40", "Pan 40 Tablet", "Glycomet 500 Tablet", "Augmentin 625 Duo Tablet"]


def load_dev_key():
    data = json.load(open(KEYS_FILE, encoding="utf-8"))
    keyid, secret_hex = next(iter(data.items()))
    return keyid, bytes.fromhex(secret_hex)


def main():
    names = sys.argv[1:] or SAMPLE
    keyid, secret = load_dev_key()

    payload = {
        "items": [{"name": n, "qty": 1} for n in names],
        "location": {"lat": 30.7411, "lon": 76.7820},   # Chandigarh, Sector 17
    }
    body = json.dumps(payload).encode("utf-8")
    ts = int(time.time())
    nonce = secrets.token_hex(8)
    signature = sign(secret, "POST", PATH, ts, nonce, body)

    req = urllib.request.Request(URL, data=body, method="POST", headers={
        "Content-Type": "application/json",
        "X-Api-Key": keyid,
        "X-Timestamp": str(ts),
        "X-Nonce": nonce,
        "X-Signature": signature,
    })
    ctx = ssl._create_unverified_context()              # dev self-signed cert only
    with urllib.request.urlopen(req, context=ctx, timeout=20) as resp:
        out = json.load(resp)

    s = out["result"]["summary"]
    print(f"HTTP 200 · {s['n_found']}/{s['n_items']} matched · "
          f"{s['n_rx_flagged']} need Rx · total savings ₹{s['total_savings_inr']}")
    for it in out["result"]["items"]:
        if not it["found"]:
            print(f"  • {it['query']}: not found"); continue
        ch = it.get("cheapest_alternative")
        tag = " ✓JanAushadhi" if (ch and ch.get("is_authoritative")) else ""
        print(f"  • {it['query']}: {it['matched']['salt']} {it['matched']['strength']} "
              f"-> cheapest {('₹%.2f/unit' % ch['unit_price']) if ch else 'n/a'}{tag}")
    print(f"  nearby pharmacies: {len(out['pharmacies'])}")


if __name__ == "__main__":
    main()

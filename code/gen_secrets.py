#!/usr/bin/env python3
"""Generate dev secrets for the API: an API key + a self-signed TLS cert.

  python3 code/gen_secrets.py

Writes (all gitignored, under secrets/):
  secrets/keys.json      {keyid: secret_hex}   — shared HMAC secret
  secrets/dev-cert.pem   self-signed TLS cert  (via openssl, dev only)
  secrets/dev-key.pem    TLS private key

Idempotent: existing files are kept. Stdlib only (secrets, json, subprocess).
"""

import json
import secrets
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SEC = ROOT / "secrets"
KEYS = SEC / "keys.json"
CERT = SEC / "dev-cert.pem"
KEYFILE = SEC / "dev-key.pem"


def main():
    SEC.mkdir(exist_ok=True)

    if KEYS.exists():
        print(f"keys exist: {KEYS} (keeping)")
    else:
        keyid = "dev-" + secrets.token_hex(4)
        secret = secrets.token_hex(32)               # 256-bit HMAC secret
        KEYS.write_text(json.dumps({keyid: secret}, indent=2), encoding="utf-8")
        KEYS.chmod(0o600)
        print(f"wrote {KEYS}\n  keyid:  {keyid}")

    if CERT.exists() and KEYFILE.exists():
        print(f"cert exists: {CERT} (keeping)")
    elif shutil.which("openssl"):
        subprocess.run([
            "openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes",
            "-keyout", str(KEYFILE), "-out", str(CERT), "-days", "365",
            "-subj", "/CN=localhost",
            "-addext", "subjectAltName=DNS:localhost,IP:127.0.0.1",
        ], check=True)
        KEYFILE.chmod(0o600)
        print(f"wrote {CERT} and {KEYFILE} (self-signed, dev only)")
    else:
        sys.exit("openssl not found — generate a cert manually:\n"
                 f"  openssl req -x509 -newkey rsa:2048 -nodes -keyout {KEYFILE} "
                 f"-out {CERT} -days 365 -subj /CN=localhost")

    print("\nStart the server:  python3 code/server.py")
    print("Call it:           python3 code/client_example.py \"Telma 40\" \"Pan 40 Tablet\"")


if __name__ == "__main__":
    main()

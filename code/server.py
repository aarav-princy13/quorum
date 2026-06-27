#!/usr/bin/env python3
"""Secure stdlib HTTPS API for the brand_to_generic pipeline.

Layers (defense in depth): TLS -> bounded concurrency -> per-IP rate limit ->
HMAC auth (replay-resistant) -> per-key rate limit -> strict input validation ->
read-only pipeline. No-content logging (health-data privacy). No frameworks.

Config via env (all optional, dev defaults under secrets/):
  B2G_DB        path to the SQLite catalog            (default data/b2g.db)
  B2G_HOST      bind host                              (default 127.0.0.1)
  B2G_PORT      bind port                              (default 8443)
  B2G_TLS_CERT  TLS certificate (PEM)                  (default secrets/dev-cert.pem)
  B2G_TLS_KEY   TLS private key (PEM)                  (default secrets/dev-key.pem)
  B2G_KEYS      API keys file {keyid: secret_hex}      (default secrets/keys.json)

Run:  python3 code/server.py     (generate secrets first: python3 code/gen_secrets.py)
"""

import json
import logging
import os
import sqlite3
import ssl
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

CODE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(CODE_DIR))
ROOT = CODE_DIR.parent

from b2g.pipeline import process_receipt, nearby_pharmacies   # noqa: E402
from b2g.security import load_keys, verify_request, NonceCache, TokenBucket  # noqa: E402

DB_PATH = os.environ.get("B2G_DB", str(ROOT / "data" / "b2g.db"))
HOST = os.environ.get("B2G_HOST", "127.0.0.1")
PORT = int(os.environ.get("B2G_PORT", "8443"))
CERT = os.environ.get("B2G_TLS_CERT", str(ROOT / "secrets" / "dev-cert.pem"))
KEYFILE = os.environ.get("B2G_TLS_KEY", str(ROOT / "secrets" / "dev-key.pem"))
KEYS_FILE = os.environ.get("B2G_KEYS", str(ROOT / "secrets" / "keys.json"))

MAX_BODY = 16 * 1024        # 16 KB
MAX_ITEMS = 50
MAX_NAME = 120
MAX_INFLIGHT = 32           # concurrent requests cap (DoS / CPU protection)
NEARBY_MAX_KM = 50          # don't call a pharmacy 12000 km away "nearby"

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s")
log = logging.getLogger("b2g.api")

# shared, thread-safe state
_KEYS = {}
_nonce = NonceCache()
_ip_limit = TokenBucket(rate_per_min=30, burst=10)
_key_limit = TokenBucket(rate_per_min=30, burst=10)
_inflight = threading.BoundedSemaphore(MAX_INFLIGHT)


def _isnum(x):
    return isinstance(x, (int, float)) and not isinstance(x, bool)


def validate_payload(obj):
    """Strictly validate the /v1/analyze body. Returns (items, location|None)."""
    if not isinstance(obj, dict):
        raise ValueError("body must be an object")
    items = obj.get("items")
    if not isinstance(items, list) or not (1 <= len(items) <= MAX_ITEMS):
        raise ValueError("items must be a list of 1..%d" % MAX_ITEMS)
    clean = []
    for it in items:
        if not isinstance(it, dict):
            raise ValueError("each item must be an object")
        name = it.get("name")
        if not isinstance(name, str) or not (1 <= len(name) <= MAX_NAME):
            raise ValueError("item.name must be a 1..%d char string" % MAX_NAME)
        qty = it.get("qty", 1)
        if not isinstance(qty, int) or isinstance(qty, bool) or not (1 <= qty <= 99):
            raise ValueError("item.qty must be an int 1..99")
        clean.append({"name": name, "qty": qty})
    loc = obj.get("location")
    location = _parse_location(loc) if loc is not None else None
    return clean, location


def _parse_location(loc):
    """Validate a {lat,lon} object into a (lat, lon) float tuple."""
    if not isinstance(loc, dict) or not _isnum(loc.get("lat")) or not _isnum(loc.get("lon")):
        raise ValueError("location must be {lat,lon} numbers")
    lat, lon = float(loc["lat"]), float(loc["lon"])
    if not (-90 <= lat <= 90 and -180 <= lon <= 180):
        raise ValueError("lat/lon out of range")
    return (lat, lon)


def validate_nearby(obj):
    """Validate the /v1/nearby body. Location is required here. Returns (lat, lon)."""
    if not isinstance(obj, dict):
        raise ValueError("body must be an object")
    loc = obj.get("location")
    if loc is None:
        raise ValueError("location is required")
    return _parse_location(loc)


def _ro_conn():
    conn = sqlite3.connect(f"file:{DB_PATH}?mode=ro", uri=True)   # read-only: API can't mutate
    conn.row_factory = sqlite3.Row
    return conn


class Handler(BaseHTTPRequestHandler):
    timeout = 15                          # per-request socket timeout (slowloris)
    protocol_version = "HTTP/1.1"

    def version_string(self):             # hide server/version banner
        return ""

    def log_message(self, *args):         # silence default (content-leaky) logging
        pass

    # ---- helpers -------------------------------------------------------
    def _send(self, status, payload, extra=None):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Strict-Transport-Security", "max-age=63072000; includeSubDomains")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("Connection", "close")
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)

    def _audit(self, status, t0, event="", keyid=""):
        # metadata only — never the body or drug names
        kid = (keyid[:6] + "…") if keyid else "-"
        log.info("%s %s %s key=%s ms=%d %s",
                 self.command, self.path, status, kid, int((time.time() - t0) * 1000), event)

    def _read_body(self):
        if self.headers.get("Transfer-Encoding"):
            return None, "chunked not supported"
        length = self.headers.get("Content-Length")
        if length is None:
            return None, "length required"
        try:
            n = int(length)
        except ValueError:
            return None, "bad length"
        if n < 0 or n > MAX_BODY:
            return None, "too large"
        return self.rfile.read(n), None

    # ---- routes --------------------------------------------------------
    def do_GET(self):
        t0 = time.time()
        if self.path == "/v1/health":
            self._send(200, {"status": "ok"})
            self._audit(200, t0)
        else:
            self._send(404, {"error": "not found"})
            self._audit(404, t0)

    def do_POST(self):
        t0 = time.time()
        if self.path not in ("/v1/analyze", "/v1/nearby"):
            self._send(404, {"error": "not found"})
            return self._audit(404, t0)

        if not _inflight.acquire(blocking=False):
            self._send(503, {"error": "busy"})
            return self._audit(503, t0, "shed")
        try:
            client_ip = self.client_address[0]
            ok, retry = _ip_limit.allow(client_ip)
            if not ok:
                self._send(429, {"error": "rate limited"}, {"Retry-After": str(retry)})
                return self._audit(429, t0, "ip_rate")

            body, err = self._read_body()
            if err:
                self._send(400, {"error": "bad request"})
                return self._audit(400, t0, err)

            ok, who = verify_request(_KEYS, _nonce, "POST", self.path, self.headers, body)
            if not ok:
                self._send(401, {"error": "unauthorized"})     # generic to client
                return self._audit(401, t0, "auth:" + who)
            keyid = who

            ok, retry = _key_limit.allow(keyid)
            if not ok:
                self._send(429, {"error": "rate limited"}, {"Retry-After": str(retry)})
                return self._audit(429, t0, "key_rate", keyid)

            try:
                obj = json.loads(body.decode("utf-8"))
                if self.path == "/v1/analyze":
                    items, location = validate_payload(obj)
                else:                                      # /v1/nearby
                    location = validate_nearby(obj)
            except (ValueError, UnicodeDecodeError, json.JSONDecodeError):
                self._send(400, {"error": "invalid payload"})
                return self._audit(400, t0, "validate", keyid)

            conn = _ro_conn()
            try:
                if self.path == "/v1/analyze":
                    result = process_receipt(conn, items)
                    pharmacies = (nearby_pharmacies(conn, lat=location[0], lon=location[1],
                                                    max_km=NEARBY_MAX_KM)
                                  if location else [])
                    payload = {"result": result, "pharmacies": pharmacies}
                else:                                      # /v1/nearby
                    pharmacies = nearby_pharmacies(conn, lat=location[0], lon=location[1],
                                                   max_km=NEARBY_MAX_KM)
                    payload = {"pharmacies": pharmacies}
            finally:
                conn.close()
            self._send(200, payload)
            self._audit(200, t0, "", keyid)
        except Exception:                              # never leak internals
            log.exception("unhandled error")           # server-side only
            try:
                self._send(500, {"error": "internal error"})
            except Exception:
                pass
            self._audit(500, t0, "exception")
        finally:
            _inflight.release()


def _build_ssl():
    if not (Path(CERT).exists() and Path(KEYFILE).exists()):
        sys.exit(f"TLS cert/key missing ({CERT}, {KEYFILE}).\n"
                 f"Generate dev secrets:  python3 code/gen_secrets.py")
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.minimum_version = ssl.TLSVersion.TLSv1_2
    ctx.load_cert_chain(CERT, KEYFILE)
    return ctx


def main():
    global _KEYS
    if not Path(KEYS_FILE).exists():
        sys.exit(f"API keys missing ({KEYS_FILE}).\n"
                 f"Generate dev secrets:  python3 code/gen_secrets.py")
    _KEYS = load_keys(KEYS_FILE)
    if not Path(DB_PATH).exists():
        sys.exit(f"DB missing ({DB_PATH}). Build it: python3 code/ingest.py")

    ctx = _build_ssl()
    httpd = ThreadingHTTPServer((HOST, PORT), Handler)
    httpd.daemon_threads = True
    httpd.socket = ctx.wrap_socket(httpd.socket, server_side=True)
    log.info("listening on https://%s:%d  (keys=%d)", HOST, PORT, len(_KEYS))
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        log.info("shutting down")
        httpd.shutdown()


if __name__ == "__main__":
    main()

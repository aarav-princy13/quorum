"""Security primitives for the API: HMAC auth (replay-resistant) + rate limiting.

Pure standard library: hmac, hashlib, json, threading, time. No third-party deps.
"""

import hashlib
import hmac
import json
import threading
import time

MAX_CLOCK_SKEW = 300        # seconds a request timestamp may differ from server time
NONCE_TTL = 600             # seconds to remember a signature (blocks replays in the window)


def load_keys(path):
    """Load {keyid: secret_bytes} from a JSON file ({keyid: secret_hex})."""
    with open(path, encoding="utf-8") as fh:
        raw = json.load(fh)
    if not isinstance(raw, dict) or not raw:
        raise ValueError("keys file must be a non-empty {keyid: secret_hex} object")
    return {kid: bytes.fromhex(sec) for kid, sec in raw.items()}


def canonical_string(method, path, timestamp, nonce, body_bytes):
    """The exact string both sign — binds method, path, time, a per-request nonce, body.

    The nonce makes every request's signature unique, so identical payloads sent in
    the same second are still distinct, while a true replay (same nonce) is caught.
    """
    body_hash = hashlib.sha256(body_bytes or b"").hexdigest()
    return "\n".join([method.upper(), path, str(timestamp), nonce, body_hash])


def sign(secret, method, path, timestamp, nonce, body_bytes):
    """Compute the hex HMAC-SHA256 signature for a request (used by the client too)."""
    msg = canonical_string(method, path, timestamp, nonce, body_bytes).encode("utf-8")
    return hmac.new(secret, msg, hashlib.sha256).hexdigest()


class NonceCache:
    """Remembers recently-seen signatures to reject replays within the skew window."""

    def __init__(self, ttl=NONCE_TTL):
        self._ttl = ttl
        self._seen = {}                      # signature -> expiry epoch
        self._lock = threading.Lock()

    def seen_before(self, signature, now):
        with self._lock:
            # opportunistic prune
            if len(self._seen) > 4096:
                self._seen = {s: e for s, e in self._seen.items() if e > now}
            if self._seen.get(signature, 0) > now:
                return True
            self._seen[signature] = now + self._ttl
            return False


def verify_request(keys, nonce_cache, method, path, headers, body_bytes, now=None):
    """Validate the HMAC auth headers. Returns (ok: bool, keyid_or_reason: str).

    Fail-closed: any missing/invalid element returns (False, reason). Reasons are for
    server-side logging only — the client always gets a generic 401.
    """
    now = int(now if now is not None else time.time())
    keyid = headers.get("X-Api-Key")
    ts = headers.get("X-Timestamp")
    sig = headers.get("X-Signature")
    nonce = headers.get("X-Nonce")
    if not (keyid and ts and sig and nonce):
        return False, "missing auth headers"
    if len(nonce) > 128:
        return False, "bad nonce"
    secret = keys.get(keyid)
    if secret is None:
        return False, "unknown keyid"
    try:
        ts_int = int(ts)
    except ValueError:
        return False, "bad timestamp"
    if abs(now - ts_int) > MAX_CLOCK_SKEW:
        return False, "timestamp outside window"
    expected = sign(secret, method, path, ts_int, nonce, body_bytes)
    if not hmac.compare_digest(expected, sig):     # constant-time
        return False, "bad signature"
    if nonce_cache.seen_before(keyid + ":" + nonce, now):
        return False, "replayed nonce"
    return True, keyid


class TokenBucket:
    """Thread-safe token-bucket rate limiter, keyed by an identifier (keyid or IP)."""

    def __init__(self, rate_per_min=30, burst=10):
        self._refill_per_sec = rate_per_min / 60.0
        self._capacity = burst
        self._state = {}                     # id -> [tokens, last_refill]
        self._lock = threading.Lock()

    def allow(self, identifier, now=None):
        """Return (allowed: bool, retry_after_seconds: int)."""
        now = now if now is not None else time.time()
        with self._lock:
            tokens, last = self._state.get(identifier, (self._capacity, now))
            tokens = min(self._capacity, tokens + (now - last) * self._refill_per_sec)
            if tokens >= 1.0:
                self._state[identifier] = (tokens - 1.0, now)
                return True, 0
            self._state[identifier] = (tokens, now)
            retry = int((1.0 - tokens) / self._refill_per_sec) + 1
            return False, retry

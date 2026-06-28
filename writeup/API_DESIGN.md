# API Design — secure stdlib HTTP service

**Date:** 2026-06-25 · stdlib only (`http.server`, `ssl`, `hmac`, `hashlib`, `json`). No frameworks.

> Honest scope: `http.server` is not a hardened public server. This is a rate-limited,
> authenticated, TLS internal API; production should still sit behind nginx/Caddy for TLS
> termination, IP filtering, and WAF. App-level hardening here is the baseline.

## Endpoints (minimal surface)
- `POST /v1/analyze` — body `{items:[{name,qty}], location?:{lat,lon}}` → pipeline result
  (matches, savings, Schedule H/H1/X safety, nearby pharmacies). **Text only; the receipt
  image is OCR'd on-device and never sent.**
- `POST /v1/nearby` — body `{location:{lat,lon}}` (required) → `{pharmacies:[...]}`. Backs the
  address-entry flow (geocode an address on-device → query here) when no device GPS is available.
  Same HMAC auth/rate-limit as analyze; signs its own path.
- **Pharmacy source: live OpenStreetMap (Overpass), per request** (`b2g/places.py`) — real, current,
  global pharmacies near the point (≈8 km, closest 8), cached in-process. Falls back to the local
  `pharmacies` snapshot table (`nearby_pharmacies`, `NEARBY_MAX_KM`=50) only if Overpass errors. The
  query host is fixed and built from validated numeric coords (SSRF-safe); user coords go to OSM to find
  nearby (inherent), the receipt image never does. Prototype-grade — production wants a managed Places API.
- `POST /v1/geocode` — body `{q}` → `{results:[{label,lat,lon}]}`. Address autocomplete backing the
  typeahead, via **Photon** (OSM, no API key), cached; returns `[]` for `<3` chars or on upstream error.
- `GET /v1/health` — `{"status":"ok"}`, nothing else.
- Everything else → 404. POST-only on analyze/nearby/geocode, JSON-only.

## Decisions (owner, 2026-06-25)
- **Auth = API key + HMAC request signing.**
- **TLS = HTTPS in the server now** (self-signed dev cert; real cert in prod).
- **Rate limit = per API key AND per IP** (defense in depth).

## Auth: API key + HMAC (replay/tamper resistant)
Each app install has a `keyid` + shared `secret`. Per request it sends:
```
X-Api-Key:    <keyid>
X-Timestamp:  <unix seconds>
X-Nonce:      <random per-request>
X-Signature:  hex( HMAC-SHA256(secret, canonical) )
  canonical = "POST\n/v1/analyze\n<timestamp>\n<nonce>\n<sha256(body)>"
```
Server: look up secret by `keyid`; recompute signature; **constant-time compare**
(`hmac.compare_digest`); reject if `|now - timestamp| > 300s` (replay window); a short-TTL
**nonce cache** (`keyid:nonce`) blocks exact replays inside the window. The nonce also makes
identical payloads in the same second distinct (no false replay rejections). Binds method +
path + timestamp + nonce + body, so tampering or replay fails even if a key leaks. **Fail closed.**

Secrets live in `secrets/keys.json` (`{keyid: secret_hex}`), gitignored, loaded at startup —
never in code. `code/gen_secrets.py` mints a dev key.

## Rate limiting (per key + per IP)
Two token buckets (sustained ~30/min, burst ~10), thread-safe. If **either** the key or the IP
bucket is empty → `429` + `Retry-After`. Plus a global in-flight concurrency cap.

## Input hardening
- Max body 16 KB (reject larger / missing / chunked). Strict JSON.
- `items`: 1–50 entries; `name`: str 1–120 chars; `qty` **optional** int 1–99 (omit = unknown).
  `location` optional, ranges checked. Unknown/oversized → `400`. (SQLi already covered by
  parameterized queries.)
- **Savings semantics:** `savings_inr_line = savings_per_unit * qty` (units bought × per-unit gap),
  never `savings_pack * qty` — the latter overstates ~pack-size×. Omitted qty falls back to one pack
  (`pack units`), the realistic minimum, so an unknown count estimates without overstating.

## Privacy & data handling
- **No-content logging:** never log drug names or bodies. Log only metadata (ts, status,
  latency, hashed keyid, rate-limit/auth events).
- **Read-only DB** connection (`mode=ro`) — the API cannot mutate the catalog.
- Stateless; nothing persisted per request.

## Leakage & transport hardening
- Strip `Server`/version banner; generic error bodies (no tracebacks/paths).
- Headers: `Strict-Transport-Security`, `X-Content-Type-Options: nosniff`,
  `Cache-Control: no-store`, `Referrer-Policy: no-referrer`.
- TLS ≥ 1.2 via `ssl.SSLContext`. CORS locked (native client → no cross-origin).
- Bounded concurrency + socket timeouts (slowloris / CPU-DoS; the fuzzy matcher is CPU-heavy).

## Files
- `b2g/security.py` — key loading, HMAC verify, nonce cache, token-bucket limiter.
- `code/server.py` — HTTPS server + handler (auth → rate limit → validate → pipeline).
- `code/gen_secrets.py` — mint a dev API key; print the self-signed-cert command.
- `code/client_example.py` — reference signed client (also the Flutter signing blueprint).

## Future hardening (noted, not in MVP)
Reverse proxy (TLS/WAF/IP allowlist), key rotation + revocation, India geofence, abuse bans
after repeated 429s, structured audit log shipping.

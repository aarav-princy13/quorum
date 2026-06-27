"""Live nearby-pharmacy lookup from OpenStreetMap (Overpass). Stdlib only.

Replaces the frozen one-area snapshot in the `pharmacies` table with REAL, current
pharmacies around any point (OSM has global coverage). Best-effort and bounded:
on timeout / rate-limit / parse error it returns None so the caller can fall back
to the local table; a successful-but-empty result returns [] (honestly "none near").

Results are cached in-process (coords rounded, short TTL) so repeat lookups for the
same area don't re-hit the public Overpass instance.

PRODUCTION NOTE: the public Overpass endpoint is rate-limited and best-effort; a
production build should use a managed Places API (or a self-hosted Overpass) and a
shared cache. The query host is fixed and the query is built only from validated
numeric coords (no user-controlled URL) — SSRF-safe.
"""

import json
import time
import urllib.parse
import urllib.request

from .util import haversine_km

_OVERPASS = "https://overpass-api.de/api/interpreter"
_UA = "brand_to_generic/0.1 (research prototype; contact: aarav10a1@gmail.com)"
_CACHE = {}            # (lat3, lon3, radius_km) -> (expiry_epoch, rows)
_CACHE_TTL = 1800.0    # 30 min


def _classify(tags):
    blob = (tags.get("name", "") + " " + tags.get("operator", "")).lower()
    if "aushadhi" in blob or "janaushadhi" in blob:
        return "jan_aushadhi"
    if "generic" in blob:
        return "generic"
    return "retail"


def parse_overpass(payload, lat, lon, limit):
    """Pure: Overpass JSON -> distance-ranked pharmacy dicts (closest `limit`).

    Separated from the network call so it can be unit-tested without Overpass.
    """
    rows = []
    for e in payload.get("elements", []):
        if "lat" not in e or "lon" not in e:
            continue
        tags = e.get("tags", {}) or {}
        rows.append({
            "name": tags.get("name") or "Pharmacy (unnamed)",
            "kind": _classify(tags),
            "city": tags.get("addr:city", "") or "",
            "area": (tags.get("addr:suburb") or tags.get("addr:neighbourhood")
                     or tags.get("addr:city") or ""),
            "lat": e["lat"],
            "lon": e["lon"],
            "distance_km": round(haversine_km(lat, lon, e["lat"], e["lon"]), 2),
            "source": "openstreetmap",
            "osm_id": e.get("id"),
        })
    rows.sort(key=lambda r: r["distance_km"])
    return rows[:limit]


def osm_nearby(lat, lon, radius_km=8.0, limit=8, timeout=7.0, now=None):
    """Live pharmacies near (lat, lon). Returns a list (possibly empty), or None on
    any failure so the caller can fall back to the local table. Cached per area."""
    now = time.time() if now is None else now
    key = (round(lat, 3), round(lon, 3), radius_km)
    cached = _CACHE.get(key)
    if cached and cached[0] > now:
        return cached[1]

    query = ('[out:json][timeout:%d];'
             'node["amenity"="pharmacy"](around:%d,%f,%f);out body %d;'
             % (int(timeout), int(radius_km * 1000), lat, lon, max(limit * 4, 40)))
    try:
        data = urllib.parse.urlencode({"data": query}).encode()
        req = urllib.request.Request(
            _OVERPASS, data=data,
            headers={"User-Agent": _UA, "Accept": "application/json"})
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            payload = json.loads(resp.read().decode("utf-8", "replace"))
    except Exception:
        return None                                    # caller falls back to DB

    rows = parse_overpass(payload, lat, lon, limit)
    _CACHE[key] = (now + _CACHE_TTL, rows)
    return rows

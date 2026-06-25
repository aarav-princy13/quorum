-- brand_to_generic — SQLite schema (stdlib sqlite3, no ORM)
-- One DB holds the drug catalog (brands + generics) and nearby pharmacies.

-- Each row is a marketed product: a brand OR a generic/Jan Aushadhi equivalent.
-- Generic matching is done on (salt, strength): same composition => substitutable.
CREATE TABLE IF NOT EXISTS drugs (
    id         INTEGER PRIMARY KEY,
    name       TEXT    NOT NULL,          -- product/brand name as printed, e.g. "Crocin 500"
    name_norm  TEXT,                      -- normalized name for fast/tolerant lookup (lowercased, depunctuated)
    salt       TEXT    NOT NULL,          -- canonicalized active composition, e.g. "paracetamol"
    strength   TEXT    NOT NULL,          -- canonicalized dose, e.g. "500mg" (may be '' if unknown)
    strength_known INTEGER NOT NULL DEFAULT 1, -- 0 = dose missing/unparseable -> not offered as a substitute
    form       TEXT,                      -- tablet / syrup / capsule ...
    mrp_inr    REAL,                      -- price in INR for the given pack
    pack       TEXT,                      -- pack description, e.g. "15 tablets"
    units      INTEGER,                   -- comparable units in the pack (tablets/ml) for per-unit pricing
    unit_price REAL,                      -- mrp_inr / units (lets us compare unlike pack sizes fairly)
    is_generic INTEGER NOT NULL DEFAULT 0,-- 1 = generic / Jan Aushadhi, 0 = brand
    is_authoritative INTEGER NOT NULL DEFAULT 0, -- 1 = official price (Jan Aushadhi/NPPA), 0 = open dataset
    schedule   TEXT    NOT NULL DEFAULT '',-- '' | 'H' | 'H1' | 'X' (Drugs & Cosmetics schedules)
    source     TEXT                       -- provenance: 'janaushadhi' | 'nppa' | 'indian-medicine-dataset' | 'seed'
);

-- Lookups: by composition (for substitution) and by name (for receipt matching).
CREATE INDEX IF NOT EXISTS idx_drugs_salt_strength ON drugs(salt, strength);
CREATE INDEX IF NOT EXISTS idx_drugs_name          ON drugs(name);
CREATE INDEX IF NOT EXISTS idx_drugs_name_norm     ON drugs(name_norm);

-- Nearby pharmacies — locations only for the MVP (no live inventory yet).
CREATE TABLE IF NOT EXISTS pharmacies (
    id     INTEGER PRIMARY KEY,
    name   TEXT NOT NULL,
    kind   TEXT,                          -- 'jan_aushadhi' | 'generic' | 'retail'
    city   TEXT,
    area   TEXT,
    lat    REAL,
    lon    REAL,
    source TEXT,                          -- 'openstreetmap' | 'seed'
    osm_id INTEGER                        -- OSM node id (provenance / dedup)
);

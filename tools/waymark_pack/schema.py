"""SQLite schema for a region pack (spec 5.3) — the single source of truth.

The Swift ``GeoData`` package (phase F2) reads this exact schema. Column names and
types here are a contract. The three deliberate global-readiness points
(``admin_unit.tier`` K6, ``wikidata_id`` K7, ``article.lang`` İ5) are baked in from v1.
"""

from __future__ import annotations

import sqlite3

from . import PACK_FORMAT_VERSION, POLYGON_FORMAT_VERSION, SCHEMA_VERSION

DDL = """
-- One region pack = one country. v1 has a single row: Turkey.
CREATE TABLE region (
    id              INTEGER PRIMARY KEY,
    iso_code        TEXT NOT NULL UNIQUE,   -- 'TR'
    name_local      TEXT NOT NULL,          -- 'Türkiye'
    name_en         TEXT NOT NULL,          -- 'Turkey'
    wikidata_id     TEXT,                   -- 'Q43'
    pack_version    INTEGER NOT NULL,
    data_date       TEXT NOT NULL
);

-- osm_admin_level -> tier mapping and user-facing labels (spec K6).
-- v1: two rows only. New country = new rows, schema unchanged.
CREATE TABLE tier_label (
    region_id       INTEGER NOT NULL REFERENCES region(id),
    tier            INTEGER NOT NULL,       -- 1, 2, 3...
    osm_admin_level INTEGER,                -- TR: tier1=4, tier2=6
    label_local     TEXT NOT NULL,          -- 'İl', 'İlçe'
    label_en        TEXT NOT NULL,          -- 'Province', 'District'
    PRIMARY KEY (region_id, tier)
);

-- ALL administrative units in one table. il/ilçe distinction is the tier column (spec K6).
CREATE TABLE admin_unit (
    id              INTEGER PRIMARY KEY,
    region_id       INTEGER NOT NULL REFERENCES region(id),
    parent_id       INTEGER REFERENCES admin_unit(id),   -- NULL for tier 1
    tier            INTEGER NOT NULL,
    name_local      TEXT NOT NULL,          -- 'Merzifon'
    name_en         TEXT,                   -- if present
    names_extra     TEXT,                   -- JSON {"fr":..,"ja":..} — NULL in v1
    osm_id          INTEGER,
    wikidata_id     TEXT,                   -- spec K7
    admin_code      TEXT,                   -- TR: plaka / TÜİK code
    population      INTEGER,
    population_year INTEGER,
    population_src  TEXT,                   -- 'tuik' | 'wikidata'
    area_km2        REAL,
    centroid_lat    REAL NOT NULL,
    centroid_lon    REAL NOT NULL
);
CREATE INDEX idx_admin_parent ON admin_unit(parent_id);
CREATE INDEX idx_admin_tier   ON admin_unit(region_id, tier);

CREATE TABLE settlement (
    id              INTEGER PRIMARY KEY,
    parent_id       INTEGER NOT NULL REFERENCES admin_unit(id),
    name_local      TEXT NOT NULL,
    name_en         TEXT,
    names_extra     TEXT,
    kind            INTEGER NOT NULL,       -- 0=village 1=town 2=hamlet 3=suburb
    geonames_id     INTEGER,
    wikidata_id     TEXT,
    lat             REAL NOT NULL,
    lon             REAL NOT NULL,
    population      INTEGER,
    elevation_m     INTEGER
);

-- History text. The lang column carries multilingual growth (spec İ5).
-- v1 produces only 'tr' and 'en' rows; a new language = a new row.
CREATE TABLE article (
    entity_kind     INTEGER NOT NULL,       -- 0=admin_unit 1=settlement
    entity_id       INTEGER NOT NULL,
    lang            TEXT NOT NULL,          -- 'tr' | 'en'
    summary         TEXT NOT NULL,
    source_url      TEXT NOT NULL,
    PRIMARY KEY (entity_kind, entity_id, lang)
);

-- Polygon geometry in a separate table so list queries never read it.
CREATE TABLE geometry (
    entity_id       INTEGER PRIMARY KEY REFERENCES admin_unit(id),
    blob            BLOB NOT NULL
);

-- Spatial pre-filter.
CREATE VIRTUAL TABLE admin_rtree      USING rtree(id, min_lon, max_lon, min_lat, max_lat);
CREATE VIRTUAL TABLE settlement_rtree USING rtree(id, min_lon, max_lon, min_lat, max_lat);

CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT);
"""

# Tables/indexes/virtual tables that must exist in a valid pack (used by tests and validate).
EXPECTED_TABLES = frozenset(
    {
        "region",
        "tier_label",
        "admin_unit",
        "settlement",
        "article",
        "geometry",
        "admin_rtree",
        "settlement_rtree",
        "meta",
    }
)

EXPECTED_INDEXES = frozenset({"idx_admin_parent", "idx_admin_tier"})

# meta keys every pack carries (spec 5.3 comment).
META_KEYS = (
    "schema_version",
    "pack_format_version",
    "polygon_format_version",
    "osm_extract_date",
    "tuik_year",
    "build_hash",
)


def connect(path: str) -> sqlite3.Connection:
    """Open a connection with the pragmas the pipeline relies on."""
    conn = sqlite3.connect(path)
    conn.execute("PRAGMA foreign_keys = ON")
    conn.execute("PRAGMA trusted_schema = ON")  # rtree needs this on some builds
    return conn


def create_all(conn: sqlite3.Connection) -> None:
    """Run the full DDL. The connection must point at a fresh (empty) database."""
    conn.executescript(DDL)
    conn.commit()


def rtree_available() -> bool:
    """True if this SQLite build has the R*Tree module compiled in."""
    probe = sqlite3.connect(":memory:")
    try:
        probe.execute("CREATE VIRTUAL TABLE _probe USING rtree(id, a, b)")
        return True
    except sqlite3.OperationalError:
        return False
    finally:
        probe.close()


def base_meta(osm_extract_date: str, tuik_year: int) -> dict[str, str]:
    """The deterministic portion of the meta table. build_hash is added last."""
    return {
        "schema_version": str(SCHEMA_VERSION),
        "pack_format_version": str(PACK_FORMAT_VERSION),
        "polygon_format_version": str(POLYGON_FORMAT_VERSION),
        "osm_extract_date": osm_extract_date,
        "tuik_year": str(tuik_year),
    }

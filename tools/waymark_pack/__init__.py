"""Waymark region-pack build pipeline (spec Section 5).

Region-agnostic: all country knowledge lives in a config file (``tools/config/*.toml``),
never in code (spec K6, K8). The pipeline turns OSM / TÜİK / Wikidata inputs into a
single SQLite ``*.pack`` file embedded in the app bundle.
"""

SCHEMA_VERSION = 1
PACK_FORMAT_VERSION = 1
POLYGON_FORMAT_VERSION = 1

__all__ = ["SCHEMA_VERSION", "PACK_FORMAT_VERSION", "POLYGON_FORMAT_VERSION"]

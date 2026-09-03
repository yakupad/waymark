"""SQLite pack writer (spec 5.2 step 7).

Takes a :class:`~waymark_pack.model.Pack` and produces the ``*.pack`` file: schema DDL,
row inserts, R*Tree population, ``meta`` table, ``VACUUM``, and a deterministic
``build_hash``.

Determinism (spec 5.2): every iteration is sorted by id; ``build_hash`` is computed over
a canonical serialisation of the content, not the file bytes (SQLite page layout is not
guaranteed stable). Two runs on the same inputs produce the same hash.
"""

from __future__ import annotations

import hashlib
import json
import sqlite3
from pathlib import Path

from . import schema
from .model import ENTITY_ADMIN_UNIT, Article, Pack
from .polygon import encode as encode_polygon


def write(pack: Pack, out_path: str | Path) -> tuple[str, dict[str, int]]:
    """Write ``pack`` to ``out_path``. Returns ``(build_hash, table_bytes)``."""
    out = Path(out_path)
    out.parent.mkdir(parents=True, exist_ok=True)
    if out.exists():
        out.unlink()

    build_hash = compute_build_hash(pack)

    conn = schema.connect(str(out))
    try:
        schema.create_all(conn)
        _insert_region(conn, pack)
        _insert_tier_labels(conn, pack)
        _insert_admin_units(conn, pack)
        _insert_settlements(conn, pack)
        _insert_articles(conn, pack.articles)
        _insert_meta(conn, pack, build_hash)
        conn.commit()
        conn.execute("VACUUM")
        conn.commit()
        table_bytes = _table_sizes(conn)
    finally:
        conn.close()

    return build_hash, table_bytes


def compute_build_hash(pack: Pack) -> str:
    """SHA-256 over a canonical JSON view of the pack content (order-independent of dict keys)."""
    payload = {
        "region": _region_dict(pack),
        "tier_labels": [
            [t.tier, t.osm_admin_level, t.label_local, t.label_en]
            for t in sorted(pack.tier_labels, key=lambda t: t.tier)
        ],
        "admin_units": [
            [
                a.id, a.tier, a.parent_id, a.name_local, a.name_en, a.names_extra,
                a.osm_id, a.wikidata_id, a.admin_code, a.population, a.population_year,
                a.population_src, _round(a.area_km2), _round(a.centroid_lat),
                _round(a.centroid_lon),
                [[r.is_hole, [[round(x, 6), round(y, 6)] for x, y in r.points]] for r in a.rings],
            ]
            for a in sorted(pack.admin_units, key=lambda a: a.id)
        ],
        "settlements": [
            [
                s.id, s.parent_id, s.name_local, s.name_en, s.names_extra, s.kind,
                s.geonames_id, s.wikidata_id, _round(s.lat), _round(s.lon),
                s.population, s.elevation_m,
            ]
            for s in sorted(pack.settlements, key=lambda s: s.id)
        ],
        "articles": [
            [a.entity_kind, a.entity_id, a.lang, a.summary, a.source_url]
            for a in sorted(pack.articles, key=lambda a: (a.entity_kind, a.entity_id, a.lang))
        ],
        "osm_extract_date": pack.osm_extract_date,
        "tuik_year": pack.tuik_year,
    }
    canonical = json.dumps(payload, sort_keys=True, ensure_ascii=False, separators=(",", ":"))
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def _insert_region(conn: sqlite3.Connection, pack: Pack) -> None:
    r = pack.region
    conn.execute(
        "INSERT INTO region (id, iso_code, name_local, name_en, wikidata_id, pack_version, data_date)"
        " VALUES (1, ?, ?, ?, ?, ?, ?)",
        (r.iso_code, r.name_local, r.name_en, r.wikidata_id, r.pack_version, r.data_date),
    )


def _insert_tier_labels(conn: sqlite3.Connection, pack: Pack) -> None:
    conn.executemany(
        "INSERT INTO tier_label (region_id, tier, osm_admin_level, label_local, label_en)"
        " VALUES (1, ?, ?, ?, ?)",
        [
            (t.tier, t.osm_admin_level, t.label_local, t.label_en)
            for t in sorted(pack.tier_labels, key=lambda t: t.tier)
        ],
    )


def _insert_admin_units(conn: sqlite3.Connection, pack: Pack) -> None:
    for a in sorted(pack.admin_units, key=lambda a: a.id):
        conn.execute(
            "INSERT INTO admin_unit (id, region_id, parent_id, tier, name_local, name_en,"
            " names_extra, osm_id, wikidata_id, admin_code, population, population_year,"
            " population_src, area_km2, centroid_lat, centroid_lon)"
            " VALUES (?, 1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (
                a.id, a.parent_id, a.tier, a.name_local, a.name_en, a.names_extra,
                a.osm_id, a.wikidata_id, a.admin_code, a.population, a.population_year,
                a.population_src, a.area_km2, a.centroid_lat, a.centroid_lon,
            ),
        )
        if a.rings:
            blob = encode_polygon(a.rings)
            conn.execute(
                "INSERT INTO geometry (entity_id, blob) VALUES (?, ?)", (a.id, blob)
            )
            min_lon, min_lat, max_lon, max_lat = _bbox_rings(a.rings)
            conn.execute(
                "INSERT INTO admin_rtree (id, min_lon, max_lon, min_lat, max_lat)"
                " VALUES (?, ?, ?, ?, ?)",
                (a.id, min_lon, max_lon, min_lat, max_lat),
            )


def _insert_settlements(conn: sqlite3.Connection, pack: Pack) -> None:
    for s in sorted(pack.settlements, key=lambda s: s.id):
        conn.execute(
            "INSERT INTO settlement (id, parent_id, name_local, name_en, names_extra, kind,"
            " geonames_id, wikidata_id, lat, lon, population, elevation_m)"
            " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (
                s.id, s.parent_id, s.name_local, s.name_en, s.names_extra, s.kind,
                s.geonames_id, s.wikidata_id, s.lat, s.lon, s.population, s.elevation_m,
            ),
        )
        conn.execute(
            "INSERT INTO settlement_rtree (id, min_lon, max_lon, min_lat, max_lat)"
            " VALUES (?, ?, ?, ?, ?)",
            (s.id, s.lon, s.lon, s.lat, s.lat),
        )


def _insert_articles(conn: sqlite3.Connection, articles: list[Article]) -> None:
    conn.executemany(
        "INSERT INTO article (entity_kind, entity_id, lang, summary, source_url)"
        " VALUES (?, ?, ?, ?, ?)",
        [
            (a.entity_kind, a.entity_id, a.lang, a.summary, a.source_url)
            for a in sorted(articles, key=lambda a: (a.entity_kind, a.entity_id, a.lang))
        ],
    )


def _insert_meta(conn: sqlite3.Connection, pack: Pack, build_hash: str) -> None:
    meta = schema.base_meta(pack.osm_extract_date, pack.tuik_year)
    meta["build_hash"] = build_hash
    conn.executemany(
        "INSERT INTO meta (key, value) VALUES (?, ?)",
        sorted(meta.items()),
    )


def _table_sizes(conn: sqlite3.Connection) -> dict[str, int]:
    """Approximate on-disk bytes per table via dbstat (falls back to row payload sizes)."""
    sizes: dict[str, int] = {}
    try:
        for name, pgsize in conn.execute(
            "SELECT name, SUM(pgsize) FROM dbstat GROUP BY name"
        ):
            if not name.startswith("sqlite_"):
                sizes[name] = int(pgsize or 0)
        if sizes:
            return sizes
    except sqlite3.OperationalError:
        pass

    for (name,) in conn.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
    ):
        try:
            total = conn.execute(
                f"SELECT SUM(LENGTH(CAST(quote(t.*) AS BLOB))) FROM \"{name}\" t"
            ).fetchone()[0]
        except sqlite3.OperationalError:
            total = 0
        sizes[name] = int(total or 0)
    return sizes


def _bbox_rings(rings) -> tuple[float, float, float, float]:
    xs = [x for r in rings for x, _ in r.points]
    ys = [y for r in rings for _, y in r.points]
    return min(xs), min(ys), max(xs), max(ys)


def _region_dict(pack: Pack) -> list:
    r = pack.region
    return [r.iso_code, r.name_local, r.name_en, r.wikidata_id, r.pack_version, r.data_date]


def _round(value, ndigits: int = 7):
    return round(value, ndigits) if isinstance(value, float) else value

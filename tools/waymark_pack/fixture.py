"""Synthetic region pack (no real inputs required).

Produces a small but schema-complete :class:`~waymark_pack.model.Pack` so that:

* phase F2 (``GeoData``) has a real ``*.pack`` file to read and test against
* the pipeline itself is testable end to end
* the polygon binary format round-trips through actual SQLite blobs

Shape: 2 tier-1 units, 3 tier-2 units (one with an enclave / inner ring — critical for
ray-casting tests), 5 settlements, a few ``tr`` articles and fewer ``en`` ones (so the
language fallback and coverage report have something to chew on).

Deterministic: identical every call, no clock, no RNG.
"""

from __future__ import annotations

from .config import RegionConfig
from .model import (
    ENTITY_ADMIN_UNIT,
    ENTITY_SETTLEMENT,
    AdminUnit,
    Article,
    Pack,
    Region,
    Settlement,
    TierLabel,
)
from .polygon import Ring


def _square(cx: float, cy: float, half: float) -> Ring:
    return Ring(
        is_hole=False,
        points=[
            (cx - half, cy - half),
            (cx + half, cy - half),
            (cx + half, cy + half),
            (cx - half, cy + half),
            (cx - half, cy - half),
        ],
    )


def _hole(cx: float, cy: float, half: float) -> Ring:
    ring = _square(cx, cy, half)
    return Ring(is_hole=True, points=list(reversed(ring.points)))


def build(cfg: RegionConfig) -> Pack:
    region = Region(
        iso_code=cfg.iso_code,
        name_local=cfg.name_local,
        name_en=cfg.name_en,
        pack_version=cfg.pack_version,
        data_date=cfg.data_date,
        wikidata_id=cfg.wikidata_id,
    )

    tier_labels = [
        TierLabel(t.tier, t.osm_admin_level, t.label_local, t.label_en) for t in cfg.tiers
    ]

    # Two tier-1 units side by side around (32, 39) and (34, 39).
    province_a = AdminUnit(
        id=1, tier=1, name_local="Test İli A", osm_id=1001,
        wikidata_id="Q1000001", admin_code="90",
        population=1_200_000, population_year=cfg.population_year, population_src=cfg.population_source,
        area_km2=5000.0, centroid_lat=39.0, centroid_lon=32.0,
        rings=[_square(32.0, 39.0, 1.0)],
    )
    province_b = AdminUnit(
        id=2, tier=1, name_local="Test İli B", osm_id=1002,
        wikidata_id="Q1000002", admin_code="91",
        population=800_000, population_year=cfg.population_year, population_src=cfg.population_source,
        area_km2=4200.0, centroid_lat=39.0, centroid_lon=34.0,
        rings=[_square(34.0, 39.0, 1.0)],
    )

    # Three tier-2 units. District C1 (in A) has an enclave: a hole at its centre that
    # belongs to district C2.
    district_c1 = AdminUnit(
        id=3, tier=2, parent_id=1, name_local="İlçe C1", osm_id=2001,
        wikidata_id="Q2000001", admin_code="9001",
        population=300_000, population_year=cfg.population_year, population_src=cfg.population_source,
        area_km2=900.0, centroid_lat=39.2, centroid_lon=31.7,
        rings=[_square(31.7, 39.2, 0.5), _hole(31.7, 39.2, 0.12)],
    )
    district_c2 = AdminUnit(
        id=4, tier=2, parent_id=1, name_local="İlçe C2", osm_id=2002,
        wikidata_id="Q2000002", admin_code="9002",
        population=150_000, population_year=cfg.population_year, population_src=cfg.population_source,
        area_km2=400.0, centroid_lat=39.2, centroid_lon=31.7,
        rings=[_square(31.7, 39.2, 0.1)],  # the enclave itself
    )
    district_d1 = AdminUnit(
        id=5, tier=2, parent_id=2, name_local="İlçe D1", osm_id=2003,
        wikidata_id="Q2000003", admin_code="9101",
        population=220_000, population_year=cfg.population_year, population_src=cfg.population_source,
        area_km2=650.0, centroid_lat=38.8, centroid_lon=34.3,
        rings=[_square(34.3, 38.8, 0.4)],
    )

    admin_units = [province_a, province_b, district_c1, district_c2, district_d1]

    settlements = [
        Settlement(id=1, parent_id=3, name_local="Köy Bir", kind=0, lat=39.05, lon=31.55,
                   wikidata_id="Q3000001", population=800, elevation_m=940),
        Settlement(id=2, parent_id=3, name_local="Kasaba İki", kind=1, lat=39.30, lon=31.90,
                   wikidata_id="Q3000002", population=6400, elevation_m=1010),
        Settlement(id=3, parent_id=4, name_local="Mezra Üç", kind=2, lat=39.20, lon=31.68,
                   population=120, elevation_m=1180),
        Settlement(id=4, parent_id=5, name_local="Köy Dört", kind=0, lat=38.75, lon=34.20,
                   wikidata_id="Q3000004", population=1500, elevation_m=760),
        Settlement(id=5, parent_id=5, name_local="Mahalle Beş", kind=3, lat=38.85, lon=34.45,
                   population=3200, elevation_m=800),
    ]

    # tr for all 5 admin units; en for only 2 -> 100% tr, 40% en coverage.
    articles = [
        Article(ENTITY_ADMIN_UNIT, 1, "tr", "Test İli A, kurgusal bir ildir.",
                "https://tr.wikipedia.org/wiki/Test_İli_A"),
        Article(ENTITY_ADMIN_UNIT, 1, "en", "Test Province A is a fictional province.",
                "https://en.wikipedia.org/wiki/Test_Province_A"),
        Article(ENTITY_ADMIN_UNIT, 2, "tr", "Test İli B, kurgusal bir ildir.",
                "https://tr.wikipedia.org/wiki/Test_İli_B"),
        Article(ENTITY_ADMIN_UNIT, 3, "tr", "İlçe C1, bir enklav içeren kurgusal ilçedir.",
                "https://tr.wikipedia.org/wiki/İlçe_C1"),
        Article(ENTITY_ADMIN_UNIT, 3, "en", "District C1 is a fictional district with an enclave.",
                "https://en.wikipedia.org/wiki/District_C1"),
        Article(ENTITY_ADMIN_UNIT, 4, "tr", "İlçe C2, İlçe C1 içinde kalan bir enklavdır.",
                "https://tr.wikipedia.org/wiki/İlçe_C2"),
        Article(ENTITY_ADMIN_UNIT, 5, "tr", "İlçe D1, Test İli B'ye bağlı kurgusal ilçedir.",
                "https://tr.wikipedia.org/wiki/İlçe_D1"),
    ]

    return Pack(
        region=region,
        tier_labels=tier_labels,
        admin_units=admin_units,
        settlements=settlements,
        articles=articles,
        osm_extract_date=cfg.osm_extract_date,
        tuik_year=cfg.population_year,
    )

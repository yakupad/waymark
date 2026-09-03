"""Intermediate data model that flows between pipeline stages.

These are plain dataclasses, independent of SQLite and shapely. ``package.py`` is the
only module that turns them into rows.
"""

from __future__ import annotations

from dataclasses import dataclass, field

from .polygon import Ring

# settlement.kind values (spec schema 5.3)
SETTLEMENT_KIND = {"village": 0, "town": 1, "hamlet": 2, "suburb": 3}

# article.entity_kind values
ENTITY_ADMIN_UNIT = 0
ENTITY_SETTLEMENT = 1


@dataclass
class RawAdminUnit:
    """A boundary relation straight out of extraction, before filtering/matching."""

    osm_id: int
    admin_level: int
    tags: dict[str, str]
    rings: list[Ring]

    @property
    def name(self) -> str:
        return self.tags.get("name", "")


@dataclass
class RawSettlement:
    osm_id: int
    place: str  # village | town | hamlet | suburb
    tags: dict[str, str]
    lat: float
    lon: float

    @property
    def name(self) -> str:
        return self.tags.get("name", "")


@dataclass
class AdminUnit:
    """A validated, matched administrative unit ready for packaging."""

    id: int
    tier: int
    name_local: str
    centroid_lat: float
    centroid_lon: float
    osm_id: int | None = None
    parent_id: int | None = None
    name_en: str | None = None
    names_extra: str | None = None
    wikidata_id: str | None = None
    admin_code: str | None = None
    population: int | None = None
    population_year: int | None = None
    population_src: str | None = None
    area_km2: float | None = None
    rings: list[Ring] = field(default_factory=list)


@dataclass
class Settlement:
    id: int
    parent_id: int
    name_local: str
    kind: int
    lat: float
    lon: float
    name_en: str | None = None
    names_extra: str | None = None
    geonames_id: int | None = None
    wikidata_id: str | None = None
    population: int | None = None
    elevation_m: int | None = None


@dataclass
class Article:
    entity_kind: int
    entity_id: int
    lang: str
    summary: str
    source_url: str


@dataclass
class Region:
    iso_code: str
    name_local: str
    name_en: str
    pack_version: int
    data_date: str
    wikidata_id: str | None = None


@dataclass
class TierLabel:
    tier: int
    osm_admin_level: int
    label_local: str
    label_en: str


@dataclass
class Pack:
    """Everything needed to write a pack file."""

    region: Region
    tier_labels: list[TierLabel]
    admin_units: list[AdminUnit]
    settlements: list[Settlement]
    articles: list[Article]
    osm_extract_date: str
    tuik_year: int

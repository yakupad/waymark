"""Region config loading and validation (spec K6, K8).

``build_pack.py`` reads one ``config/*.toml`` file. All country-specific values —
ISO code, ``osm_admin_level -> tier`` map, tier labels, expected unit counts, input
paths — come from here. The pipeline code is region-agnostic.
"""

from __future__ import annotations

import tomllib
from dataclasses import dataclass, field
from pathlib import Path


class ConfigError(Exception):
    """Raised when a config file is missing required keys or is internally inconsistent."""


@dataclass(frozen=True)
class TierConfig:
    tier: int
    osm_admin_level: int
    label_local: str
    label_en: str
    expected_count: int
    iso3166_2_prefix: str | None = None
    max_intersection_report_threshold: float = 0.5
    # Real OSM data drifts from the target count as districts are created/merged. A
    # fraction of `expected_count` that `actual` may differ by before it's a failure.
    count_tolerance: float = 0.0


@dataclass(frozen=True)
class RegionConfig:
    # [region]
    iso_code: str
    name_local: str
    name_en: str
    wikidata_id: str | None
    pack_version: int
    data_date: str

    # [locale]
    name_normalization: str

    # [[tier]]
    tiers: list[TierConfig]

    # [content]
    languages: list[str]
    wikipedia_api: str
    min_coverage_warn: float

    # [population]
    population_source: str
    population_year: int

    # [simplify]
    simplify_tolerance_deg: float

    # [inputs] — resolved to absolute paths against repo root
    osm_pbf: Path
    tuik_csv: Path
    wikidata_json: Path

    # [meta]
    osm_extract_date: str

    # provenance
    source_path: Path = field(default_factory=Path)

    @property
    def tier_by_level(self) -> dict[int, TierConfig]:
        return {t.osm_admin_level: t for t in self.tiers}

    @property
    def tier_by_number(self) -> dict[int, TierConfig]:
        return {t.tier: t for t in self.tiers}


def load(config_path: str | Path, repo_root: str | Path | None = None) -> RegionConfig:
    """Parse and validate a region config file."""
    path = Path(config_path).resolve()
    if not path.is_file():
        raise ConfigError(f"config file not found: {path}")

    root = Path(repo_root).resolve() if repo_root else _find_repo_root(path)

    with path.open("rb") as fh:
        raw = tomllib.load(fh)

    try:
        region = raw["region"]
        locale = raw["locale"]
        content = raw["content"]
        population = raw["population"]
        simplify = raw["simplify"]
        inputs = raw["inputs"]
        meta = raw["meta"]
        tier_tables = raw["tier"]
    except KeyError as exc:
        raise ConfigError(f"{path.name}: missing required table {exc}") from exc

    if not tier_tables:
        raise ConfigError(f"{path.name}: at least one [[tier]] entry is required")

    tiers = [_parse_tier(t, path.name) for t in tier_tables]
    _validate_tiers(tiers, path.name)

    languages = list(content["languages"])
    if not languages:
        raise ConfigError(f"{path.name}: content.languages must not be empty")

    return RegionConfig(
        iso_code=str(region["iso_code"]),
        name_local=str(region["name_local"]),
        name_en=str(region["name_en"]),
        wikidata_id=_opt_str(region.get("wikidata_id")),
        pack_version=int(region["pack_version"]),
        data_date=str(region["data_date"]),
        name_normalization=str(locale["name_normalization"]),
        tiers=tiers,
        languages=languages,
        wikipedia_api=str(content["wikipedia_api"]),
        min_coverage_warn=float(content["min_coverage_warn"]),
        population_source=str(population["source"]),
        population_year=int(population["year"]),
        simplify_tolerance_deg=float(simplify["tolerance_deg"]),
        osm_pbf=(root / inputs["osm_pbf"]).resolve(),
        tuik_csv=(root / inputs["tuik_csv"]).resolve(),
        wikidata_json=(root / inputs["wikidata_json"]).resolve(),
        osm_extract_date=str(meta["osm_extract_date"]),
        source_path=path,
    )


def _parse_tier(table: dict, filename: str) -> TierConfig:
    try:
        return TierConfig(
            tier=int(table["tier"]),
            osm_admin_level=int(table["osm_admin_level"]),
            label_local=str(table["label_local"]),
            label_en=str(table["label_en"]),
            expected_count=int(table["expected_count"]),
            iso3166_2_prefix=_opt_str(table.get("iso3166_2_prefix")),
            max_intersection_report_threshold=float(
                table.get("max_intersection_report_threshold", 0.5)
            ),
            count_tolerance=float(table.get("count_tolerance", 0.0)),
        )
    except KeyError as exc:
        raise ConfigError(f"{filename}: [[tier]] missing key {exc}") from exc


def _validate_tiers(tiers: list[TierConfig], filename: str) -> None:
    numbers = [t.tier for t in tiers]
    if numbers != sorted(numbers) or len(set(numbers)) != len(numbers):
        raise ConfigError(f"{filename}: tier numbers must be unique and ascending: {numbers}")
    if numbers[0] != 1:
        raise ConfigError(f"{filename}: tiers must start at 1, got {numbers[0]}")
    if numbers != list(range(1, len(numbers) + 1)):
        raise ConfigError(f"{filename}: tier numbers must be contiguous: {numbers}")
    levels = [t.osm_admin_level for t in tiers]
    if len(set(levels)) != len(levels):
        raise ConfigError(f"{filename}: osm_admin_level values must be unique: {levels}")


def _opt_str(value) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def _find_repo_root(start: Path) -> Path:
    for parent in [start, *start.parents]:
        if (parent / ".git").exists() or (parent / "waymark-spec.md").is_file():
            return parent
    return start.parent

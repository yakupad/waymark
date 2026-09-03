"""Two-stage country filter (spec 5.2 step 2, R1b).

The Geofabrik Turkey extract contains units from 8 neighbouring countries. Measured:

* tier 1: ``ISO3166-2=TR-*`` tag matches 81/81 exactly — use the tag.
* tier 2: the same tag matches 0/973 (ISO 3166-2 only defines provinces for TR) — assign
  each district to the tier-1 polygon it has MAXIMUM INTERSECTION AREA with. Centroid
  tests fail for crescent-shaped coastal districts whose centroid lies outside the
  polygon. This single pass drops foreign districts and sets ``parent_id``.

shapely is imported lazily: ``assign_tier2_parents`` needs it, the tag-based
``keep_tier1`` does not.
"""

from __future__ import annotations

from dataclasses import dataclass

from .match import plaka_from_iso3166_2


@dataclass
class Tier1Match:
    osm_id: int
    admin_code: str  # plaka


@dataclass
class Tier2Assignment:
    osm_id: int
    parent_osm_id: int | None       # None -> dropped (foreign or no overlap)
    intersection_ratio: float       # matched area / own area; < threshold is suspicious


def keep_tier1(units, iso3166_2_prefix: str) -> tuple[list[Tier1Match], list[int]]:
    """Partition tier-1 candidates by the ``ISO3166-2`` tag.

    ``units`` is any iterable of objects exposing ``.osm_id`` and ``.tags``. Returns
    ``(kept, dropped_osm_ids)``.
    """
    kept: list[Tier1Match] = []
    dropped: list[int] = []
    for unit in units:
        raw = unit.tags.get("ISO3166-2") or unit.tags.get("ref:INSEE") or ""
        code = plaka_from_iso3166_2(raw, iso3166_2_prefix)
        if code is None:
            dropped.append(unit.osm_id)
        else:
            kept.append(Tier1Match(osm_id=unit.osm_id, admin_code=code))
    return kept, dropped


def assign_tier2_parents(tier2_units, tier1_polygons: dict[int, "object"]):
    """Assign each tier-2 unit to its maximum-overlap tier-1 parent.

    ``tier2_units`` items expose ``.osm_id`` and ``.rings`` (list of
    :class:`~waymark_pack.polygon.Ring`). ``tier1_polygons`` maps tier-1 osm_id to a
    shapely geometry. Returns a list of :class:`Tier2Assignment`.
    """
    from shapely.geometry import Polygon
    from shapely.validation import make_valid

    results: list[Tier2Assignment] = []
    for unit in tier2_units:
        geom = _shapely_from_rings(unit.rings, Polygon, make_valid)
        if geom is None or geom.is_empty:
            results.append(Tier2Assignment(unit.osm_id, None, 0.0))
            continue

        own_area = geom.area or 1e-12
        best_parent: int | None = None
        best_ratio = 0.0
        for parent_osm_id, parent_geom in tier1_polygons.items():
            if not geom.intersects(parent_geom):
                continue
            ratio = geom.intersection(parent_geom).area / own_area
            if ratio > best_ratio:
                best_ratio = ratio
                best_parent = parent_osm_id

        results.append(Tier2Assignment(unit.osm_id, best_parent, best_ratio))
    return results


def suspicious(assignments: list[Tier2Assignment], threshold: float) -> list[Tier2Assignment]:
    """Assignments that matched a parent but with a low overlap ratio."""
    return [
        a
        for a in assignments
        if a.parent_osm_id is not None and a.intersection_ratio < threshold
    ]


def _shapely_from_rings(rings, polygon_cls, make_valid):
    outer = [r for r in rings if not r.is_hole]
    holes = [r for r in rings if r.is_hole]
    if not outer:
        return None
    geom = polygon_cls(outer[0].points, [h.points for h in holes])
    if not geom.is_valid:
        geom = make_valid(geom)
    return geom

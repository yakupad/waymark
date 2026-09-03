"""Country filter — spec 5.2 step 2, R1b.

tier-1: ISO3166-2 tag. tier-2: maximum intersection area with a validated tier-1 polygon.
"""

from dataclasses import dataclass

import pytest

from waymark_pack import country_filter
from waymark_pack.polygon import Ring

shapely = pytest.importorskip("shapely")
from shapely.geometry import Polygon  # noqa: E402


@dataclass
class FakeUnit:
    osm_id: int
    tags: dict
    rings: list


def _square(cx, cy, h):
    return [Ring(False, [
        (cx - h, cy - h), (cx + h, cy - h), (cx + h, cy + h),
        (cx - h, cy + h), (cx - h, cy - h),
    ])]


def test_keep_tier1_partitions_on_iso_tag():
    units = [
        FakeUnit(1, {"ISO3166-2": "TR-34"}, []),
        FakeUnit(2, {"ISO3166-2": "TR-06"}, []),
        FakeUnit(3, {"ISO3166-2": "GE-AB"}, []),   # Georgia — dropped
        FakeUnit(4, {"name": "ناحية"}, []),          # no tag — dropped
    ]
    kept, dropped = country_filter.keep_tier1(units, "TR-")
    assert {m.osm_id for m in kept} == {1, 2}
    assert {m.admin_code for m in kept} == {"34", "06"}
    assert set(dropped) == {3, 4}


def test_tier2_assigned_to_max_overlap_parent():
    parent_a = Polygon(_square(0, 0, 1)[0].points)
    parent_b = Polygon(_square(3, 0, 1)[0].points)
    tier1 = {10: parent_a, 20: parent_b}

    # district mostly inside A, slightly crossing toward B's side
    district = FakeUnit(100, {}, _square(0.3, 0, 0.5))
    foreign = FakeUnit(200, {}, _square(50, 50, 1))  # nowhere near either parent

    result = country_filter.assign_tier2_parents([district, foreign], tier1)
    by_id = {a.osm_id: a for a in result}
    assert by_id[100].parent_osm_id == 10
    assert by_id[100].intersection_ratio > 0.5
    assert by_id[200].parent_osm_id is None


def test_centroid_outside_polygon_still_matches_by_area():
    # C-shaped (crescent) parent: centroid falls in the notch, outside the polygon.
    crescent = Polygon([
        (0, 0), (4, 0), (4, 4), (0, 4), (0, 3),
        (3, 3), (3, 1), (0, 1), (0, 0),
    ])
    assert not crescent.contains(crescent.centroid)
    tier1 = {1: crescent}
    district = FakeUnit(5, {}, [Ring(False, [
        (0.1, 0.1), (2.5, 0.1), (2.5, 0.9), (0.1, 0.9), (0.1, 0.1),
    ])])
    result = country_filter.assign_tier2_parents([district], tier1)
    assert result[0].parent_osm_id == 1


def test_suspicious_flags_low_overlap():
    a = country_filter.Tier2Assignment(1, 10, 0.3)
    b = country_filter.Tier2Assignment(2, 10, 0.9)
    c = country_filter.Tier2Assignment(3, None, 0.0)
    assert country_filter.suspicious([a, b, c], 0.5) == [a]

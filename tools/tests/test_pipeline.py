"""Real-build pipeline path (spec 5.2 Adımlar) with a synthetic extraction.

``extract.run`` is monkeypatched so we exercise country filter -> validate -> simplify ->
assemble -> package without needing osmium or a 600 MB PBF.
"""

import pytest

from waymark_pack import extract, pipeline
from waymark_pack.model import RawAdminUnit, RawSettlement
from waymark_pack.polygon import Ring

pytest.importorskip("shapely")


def _sq(cx, cy, h, hole=False):
    return Ring(hole, [
        (cx - h, cy - h), (cx + h, cy - h), (cx + h, cy + h),
        (cx - h, cy + h), (cx - h, cy - h),
    ])


def _fake_extract(province_count=2, district_per_province=2, extras=()):
    """Build a grid of provinces each with N districts, plus optional junk relations."""
    admin = []
    osm = 1000
    for p in range(province_count):
        cx = 30.0 + p * 3.0
        admin.append(RawAdminUnit(
            osm_id=osm, admin_level=4,
            tags={"name": f"Province {p}", "ISO3166-2": f"TR-{p + 1:02d}"},
            rings=[_sq(cx, 39.0, 1.2)],
        ))
        prov_osm = osm
        osm += 1
        for d in range(district_per_province):
            admin.append(RawAdminUnit(
                osm_id=osm, admin_level=6,
                tags={"name": f"District {p}-{d}"},
                rings=[_sq(cx - 0.5 + d * 0.6, 39.0, 0.35)],
            ))
            osm += 1
    for e in extras:
        admin.append(e)
    settlements = [
        RawSettlement(osm_id=9001, place="village", tags={"name": "Köy"}, lat=39.0, lon=30.0),
    ]
    return admin, settlements


@pytest.fixture
def patched(monkeypatch):
    def _apply(admin, settlements):
        monkeypatch.setattr(extract, "run", lambda inputs: (admin, settlements))
    return _apply


def _cfg_with_counts(tr_config, t1, t2):
    # shrink the expected counts so a small synthetic set can pass validation
    object.__setattr__(tr_config.tiers[0], "expected_count", t1)
    object.__setattr__(tr_config.tiers[1], "expected_count", t2)
    return tr_config


def test_check_only_stops_after_validation(tr_config, patched, tmp_path):
    patched(*_fake_extract(2, 2))
    _cfg_with_counts(tr_config, 2, 4)
    rep = pipeline.run(tr_config, None, check_only=True, offline=True)
    assert rep.counts_ok
    assert [tc.actual for tc in rep.tier_counts] == [2, 4]


def test_count_mismatch_fails_the_build(tr_config, patched, tmp_path):
    patched(*_fake_extract(2, 2))
    _cfg_with_counts(tr_config, 81, 973)  # synthetic set can't reach the real target
    with pytest.raises(pipeline.PipelineError, match="count validation failed"):
        pipeline.run(tr_config, tmp_path / "out.pack", offline=True)


def test_invalid_admin_level_is_skipped_not_fatal(tr_config, patched, tmp_path):
    junk = RawAdminUnit(osm_id=88, admin_level=88, tags={"name": "typo"}, rings=[_sq(30, 39, 0.1)])
    patched(*_fake_extract(2, 2, extras=[junk]))
    _cfg_with_counts(tr_config, 2, 4)
    rep = pipeline.run(tr_config, tmp_path / "out.pack", offline=True)
    assert any("admin_level=88" in s for s in rep.skipped_records)
    assert rep.counts_ok


def test_foreign_tier1_without_iso_tag_is_dropped(tr_config, patched, tmp_path):
    foreign = RawAdminUnit(
        osm_id=500, admin_level=4, tags={"name": "ناحية"}, rings=[_sq(90, 39, 1.0)]
    )
    patched(*_fake_extract(2, 2, extras=[foreign]))
    _cfg_with_counts(tr_config, 2, 4)
    rep = pipeline.run(tr_config, tmp_path / "out.pack", offline=True)
    assert rep.tier_counts[0].actual == 2  # foreign province not counted


def test_full_build_writes_pack_and_hash(tr_config, patched, tmp_path):
    patched(*_fake_extract(2, 3))
    _cfg_with_counts(tr_config, 2, 6)
    out = tmp_path / "out.pack"
    rep = pipeline.run(tr_config, out, offline=True)
    assert out.is_file()
    assert len(rep.build_hash) == 64
    assert rep.table_bytes

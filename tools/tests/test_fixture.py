"""Fixture pack — a schema-complete synthetic pack, no real inputs (spec F2 support)."""

from waymark_pack import fixture, schema
from waymark_pack.package import write
from waymark_pack.polygon import decode


def test_fixture_builds_a_valid_pack(tr_config, tmp_path):
    pack = fixture.build(tr_config)
    out = tmp_path / "tr.pack"
    build_hash, table_bytes = write(pack, out)

    assert out.is_file()
    assert len(build_hash) == 64
    assert table_bytes  # non-empty size report

    conn = schema.connect(str(out))
    try:
        tables = {r[0] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        assert schema.EXPECTED_TABLES <= tables

        assert conn.execute("SELECT COUNT(*) FROM region").fetchone()[0] == 1
        assert conn.execute("SELECT COUNT(*) FROM tier_label").fetchone()[0] == 2

        by_tier = dict(conn.execute("SELECT tier, COUNT(*) FROM admin_unit GROUP BY tier"))
        assert by_tier == {1: 2, 2: 3}

        # tier-1 units have no parent, tier-2 units do
        assert conn.execute(
            "SELECT COUNT(*) FROM admin_unit WHERE tier=1 AND parent_id IS NOT NULL"
        ).fetchone()[0] == 0
        assert conn.execute(
            "SELECT COUNT(*) FROM admin_unit WHERE tier=2 AND parent_id IS NULL"
        ).fetchone()[0] == 0

        assert conn.execute("SELECT COUNT(*) FROM settlement").fetchone()[0] == 5
        assert conn.execute("SELECT COUNT(*) FROM admin_rtree").fetchone()[0] == 5
        assert conn.execute("SELECT COUNT(*) FROM settlement_rtree").fetchone()[0] == 5
    finally:
        conn.close()


def test_fixture_has_an_enclave_polygon(tr_config, tmp_path):
    pack = fixture.build(tr_config)
    out = tmp_path / "tr.pack"
    write(pack, out)

    conn = schema.connect(str(out))
    try:
        # İlçe C1 (id 3) carries an inner ring
        (blob,) = conn.execute("SELECT blob FROM geometry WHERE entity_id=3").fetchone()
        rings = decode(blob)
        assert any(r.is_hole for r in rings), "fixture must exercise the enclave path"
    finally:
        conn.close()


def test_fixture_wikidata_ids_and_population_source(tr_config, tmp_path):
    pack = fixture.build(tr_config)
    out = tmp_path / "tr.pack"
    write(pack, out)

    conn = schema.connect(str(out))
    try:
        # K7: every admin unit carries a wikidata_id
        assert conn.execute(
            "SELECT COUNT(*) FROM admin_unit WHERE wikidata_id IS NULL"
        ).fetchone()[0] == 0
        # K7 v1: population comes from TÜİK
        srcs = {r[0] for r in conn.execute(
            "SELECT DISTINCT population_src FROM admin_unit WHERE population IS NOT NULL"
        )}
        assert srcs == {"tuik"}
    finally:
        conn.close()


def test_fixture_article_language_fallback_shape(tr_config, tmp_path):
    pack = fixture.build(tr_config)
    out = tmp_path / "tr.pack"
    write(pack, out)

    conn = schema.connect(str(out))
    try:
        tr = conn.execute("SELECT COUNT(*) FROM article WHERE lang='tr'").fetchone()[0]
        en = conn.execute("SELECT COUNT(*) FROM article WHERE lang='en'").fetchone()[0]
        assert tr == 5 and en == 2  # İ4: EN coverage is legitimately lower
    finally:
        conn.close()

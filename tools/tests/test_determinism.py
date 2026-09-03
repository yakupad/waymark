"""Determinism — spec 5.2: same input -> same output (verified by hash)."""

import sqlite3

from waymark_pack import fixture
from waymark_pack.package import compute_build_hash, write


def test_build_hash_stable_across_runs(tr_config):
    h1 = compute_build_hash(fixture.build(tr_config))
    h2 = compute_build_hash(fixture.build(tr_config))
    assert h1 == h2


def test_build_hash_changes_when_content_changes(tr_config):
    pack = fixture.build(tr_config)
    base = compute_build_hash(pack)
    pack.admin_units[0].population += 1
    assert compute_build_hash(pack) != base


def test_two_written_packs_share_build_hash(tr_config, tmp_path):
    a = tmp_path / "a.pack"
    b = tmp_path / "b.pack"
    ha, _ = write(fixture.build(tr_config), a)
    hb, _ = write(fixture.build(tr_config), b)
    assert ha == hb

    for path, expected in ((a, ha), (b, hb)):
        conn = sqlite3.connect(path)
        try:
            (stored,) = conn.execute("SELECT value FROM meta WHERE key='build_hash'").fetchone()
            assert stored == expected
        finally:
            conn.close()


def test_row_order_is_sorted_by_id(tr_config, tmp_path):
    out = tmp_path / "tr.pack"
    write(fixture.build(tr_config), out)
    conn = sqlite3.connect(out)
    try:
        ids = [r[0] for r in conn.execute("SELECT id FROM admin_unit")]
        assert ids == sorted(ids)
    finally:
        conn.close()

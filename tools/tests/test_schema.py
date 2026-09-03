"""Schema DDL — spec 5.3. Every table/index/rtree must be creatable."""

import sqlite3

import pytest

from waymark_pack import schema


@pytest.fixture
def db():
    conn = schema.connect(":memory:")
    schema.create_all(conn)
    yield conn
    conn.close()


def test_all_expected_tables_exist(db):
    names = {
        row[0]
        for row in db.execute(
            "SELECT name FROM sqlite_master WHERE type IN ('table')"
        )
    }
    assert schema.EXPECTED_TABLES <= names


def test_expected_indexes_exist(db):
    names = {
        row[0]
        for row in db.execute("SELECT name FROM sqlite_master WHERE type='index'")
    }
    assert schema.EXPECTED_INDEXES <= names


def test_rtree_module_is_available():
    assert schema.rtree_available(), "this SQLite build lacks R*Tree — pack cannot be built"


def test_rtree_tables_accept_rows(db):
    db.execute("INSERT INTO admin_rtree VALUES (1, 26.0, 27.0, 38.0, 39.0)")
    db.execute("INSERT INTO settlement_rtree VALUES (1, 26.5, 26.5, 38.5, 38.5)")
    hits = db.execute(
        "SELECT id FROM admin_rtree WHERE min_lon <= 26.5 AND max_lon >= 26.5"
    ).fetchall()
    assert hits == [(1,)]


def test_foreign_key_enforced_on_geometry(db):
    db.execute(
        "INSERT INTO region (id, iso_code, name_local, name_en, pack_version, data_date)"
        " VALUES (1, 'TR', 'Türkiye', 'Turkey', 1, '2024-01-01')"
    )
    with pytest.raises(sqlite3.IntegrityError):
        db.execute("INSERT INTO geometry (entity_id, blob) VALUES (999, X'00')")


def test_article_primary_key_is_kind_id_lang(db):
    db.execute(
        "INSERT INTO article VALUES (0, 1, 'tr', 'a', 'http://x')"
    )
    db.execute("INSERT INTO article VALUES (0, 1, 'en', 'b', 'http://x')")  # ok, different lang
    with pytest.raises(sqlite3.IntegrityError):
        db.execute("INSERT INTO article VALUES (0, 1, 'tr', 'c', 'http://x')")


def test_base_meta_keys(db):
    meta = schema.base_meta("2024-01-01", 2023)
    assert set(meta) == {
        "schema_version",
        "pack_format_version",
        "polygon_format_version",
        "osm_extract_date",
        "tuik_year",
    }

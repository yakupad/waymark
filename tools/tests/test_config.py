"""Region config loading and validation (spec K6, K8)."""

import textwrap

import pytest

from waymark_pack import config as config_mod


def test_tr_config_loads(tr_config):
    assert tr_config.iso_code == "TR"
    assert tr_config.name_normalization == "tr_TR"
    assert [t.tier for t in tr_config.tiers] == [1, 2]
    assert tr_config.tier_by_number[1].expected_count == 81
    assert tr_config.tier_by_number[2].expected_count == 973
    assert tr_config.tier_by_level[4].label_local == "İl"
    assert tr_config.languages == ["tr", "en"]


def _write(tmp_path, body: str):
    p = tmp_path / "x.toml"
    p.write_text(textwrap.dedent(body), encoding="utf-8")
    return p


_MINIMAL = """
    [region]
    iso_code = "XX"
    name_local = "X"
    name_en = "X"
    pack_version = 1
    data_date = "2024-01-01"
    [locale]
    name_normalization = "und"
    [content]
    languages = ["en"]
    wikipedia_api = "https://{lang}/{title}"
    min_coverage_warn = 0.4
    [population]
    source = "wikidata"
    year = 2023
    [simplify]
    tolerance_deg = 0.001
    [inputs]
    osm_pbf = "a"
    tuik_csv = "b"
    wikidata_json = "c"
    [meta]
    osm_extract_date = "2024-01-01"
"""


def test_missing_table_is_a_config_error(tmp_path):
    p = _write(tmp_path, _MINIMAL.replace('[locale]\n    name_normalization = "und"', ""))
    with pytest.raises(config_mod.ConfigError):
        config_mod.load(p, repo_root=tmp_path)


def test_tiers_must_start_at_one(tmp_path):
    p = _write(tmp_path, _MINIMAL + """
        [[tier]]
        tier = 2
        osm_admin_level = 6
        label_local = "d"
        label_en = "d"
        expected_count = 10
    """)
    with pytest.raises(config_mod.ConfigError, match="start at 1"):
        config_mod.load(p, repo_root=tmp_path)


def test_tiers_must_be_contiguous(tmp_path):
    p = _write(tmp_path, _MINIMAL + """
        [[tier]]
        tier = 1
        osm_admin_level = 4
        label_local = "p"
        label_en = "p"
        expected_count = 81
        [[tier]]
        tier = 3
        osm_admin_level = 6
        label_local = "d"
        label_en = "d"
        expected_count = 973
    """)
    with pytest.raises(config_mod.ConfigError, match="contiguous"):
        config_mod.load(p, repo_root=tmp_path)


def test_input_paths_resolved_against_repo_root(tmp_path):
    p = _write(tmp_path, _MINIMAL + """
        [[tier]]
        tier = 1
        osm_admin_level = 4
        label_local = "p"
        label_en = "p"
        expected_count = 81
    """)
    cfg = config_mod.load(p, repo_root=tmp_path)
    assert cfg.osm_pbf == (tmp_path / "a").resolve()

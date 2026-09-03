# Waymark pack pipeline (`build_pack.py`)

Turns OpenStreetMap + TÜİK + Wikidata data into a single embedded SQLite pack
(`tr.pack`) for the app. Spec: `waymark-spec.md` Section 5 and prompt P1.

This is **phase F1**. It locks two contracts that every later phase depends on:

1. the **pack SQLite schema** — `waymark_pack/schema.py` (spec 5.3)
2. the **polygon binary format** — `waymark_pack/polygon.py` (spec 5.4).
   The Swift `PolygonDecoder` in the `GeoData` package (F2) decodes exactly this.

The pipeline is **region-agnostic** (spec K6, K8): all country knowledge lives in
`config/*.toml`. A new country is a new config file, never a code change. v1 ships
one config: `config/tr.toml`.

## Setup

```bash
cd tools
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
brew install osmium-tool          # only needed for a real build, not --fixture
```

## Usage

```bash
# from the repo root

# synthetic pack — no inputs, for F2 development and CI
python3 -m tools.build_pack --config tools/config/tr.toml --out build/tr.pack --fixture

# validate the real inputs, stop after the 81 / 973 count check
python3 -m tools.build_pack --config tools/config/tr.toml --check

# full real build
python3 -m tools.build_pack --config tools/config/tr.toml --out build/tr.pack --report build/report.txt
```

Exit codes: `0` success, `1` pipeline/validation failure, `2` bad invocation or
missing inputs.

## Real inputs (not in the repo)

Place these under `tools/data/` (git-ignored). Paths are set in `config/tr.toml`
under `[inputs]`.

### 1. `turkey-latest.osm.pbf`

```bash
curl -L -o tools/data/turkey-latest.osm.pbf \
  https://download.geofabrik.de/europe/turkey-latest.osm.pbf
```

~614 MB. The extract crosses the border — it also contains units from 8
neighbouring countries. The pipeline's two-stage country filter (spec 5.2 step 2)
removes them: tier-1 by the `ISO3166-2=TR-*` tag, tier-2 by maximum intersection
area with a validated province polygon.

### 2. `tuik-adnks.csv`

TÜİK Adrese Dayalı Nüfus Kayıt Sistemi (ADNKS) population figures. CSV with at
least a code column (`code` / `kod` / `plaka`) and a population column
(`population` / `nufus`). Optional `year`. The join to OSM goes through the
**administrative code**, never the name (spec 5.2 step 5: 28 name collisions).

Source: <https://data.tuik.gov.tr/> → "Adrese Dayalı Nüfus Kayıt Sistemi Sonuçları".

### 3. `wikidata-tr.json`

Output of this SPARQL query (run at <https://query.wikidata.org/>, download as JSON):

```sparql
SELECT ?item ?osmId ?nameEn ?population WHERE {
  ?item wdt:P17 wd:Q43 .                       # country = Turkey
  ?item wdt:P31/wdt:P279* wd:Q15284 .          # instance of / subclass of: admin territorial entity
  OPTIONAL { ?item wdt:P402 ?osmId. }          # OSM relation id
  OPTIONAL { ?item wdt:P1082 ?population. }     # population
  OPTIONAL { ?item rdfs:label ?nameEn. FILTER(LANG(?nameEn) = "en") }
}
```

The pipeline also accepts a pre-flattened
`[{ "osm_id": ..., "wikidata_id": "Q...", "name_en": ..., "population": ... }]`.

Wikidata is **CC0** — no attribution burden (spec K7).

## Reports

Every build prints, and `--report` writes, a summary:

- unit counts vs the config's `expected_count` (81 / 973) — a mismatch is a **hard error**
- tag-based vs geometry-based filter counts (cross-check)
- skipped records (invalid `admin_level` like the one `88` typo) — skipped, not fatal
- name collisions (28 expected for TR) — reported, not an error
- suspicious tier-2 parent assignments (overlap < 50%)
- per-language Wikipedia coverage — below `min_coverage_warn` flags the EN content
  strategy (spec R13)
- pack size per table (hard ceiling 20 MB, spec 5.5)

## Determinism

Same inputs → same `build_hash` (SHA-256 over a canonical view of the content,
stored in `meta`). Row order is sorted by id; timestamps come from the config's
`data_date`, never the wall clock. Verified by `tests/test_determinism.py`.

## Tests

```bash
python3 -m pytest tools/tests -q
```

Covers: polygon encode/decode round-trip and every spec 12.1 corruption case,
schema DDL, the two-stage country filter (including the crescent/centroid case),
Turkish name normalisation (the `İ`/`ı` trap), the fixture pack, the real-build
pipeline path with a synthetic extraction, and determinism.

## Module map

| Module | Responsibility |
|---|---|
| `config.py` | load + validate `config/*.toml` into `RegionConfig` |
| `schema.py` | spec 5.3 DDL — single source of truth |
| `polygon.py` | spec 5.4 binary format — encode + decode (shared with Swift) |
| `model.py` | intermediate dataclasses between stages |
| `extract.py` | `osmium` CLI wrapper: boundary relations + place nodes |
| `country_filter.py` | two-stage TR / neighbour separation |
| `simplify.py` | shapely `simplify(0.001, preserve_topology=True)` |
| `match.py` | Turkish-aware name folding, plaka extraction, collision detection |
| `enrich.py` | TÜİK CSV + Wikidata JSON parsing |
| `content.py` | Wikipedia REST summaries (tier 1-2 only), coverage report |
| `package.py` | SQLite writer, R*Tree, VACUUM, `build_hash`, size report |
| `report.py` | `BuildReport` structure + text rendering |
| `fixture.py` | synthetic pack generator |
| `pipeline.py` | stage orchestration (`run`, `run_fixture`) |

"""Population and Wikidata enrichment (spec K7).

Every unit carries a ``wikidata_id`` (K7: CC0, no attribution burden, already linked from
OSM via ``wikidata=*``). v1 fills the column but takes population from TÜİK, marking it
``population_src='tuik'``. v2+ countries switch to Wikidata's P1082.

TÜİK is joined by administrative code, never by name (spec 5.2 step 5).
"""

from __future__ import annotations

import csv
import json
from dataclasses import dataclass
from pathlib import Path


class EnrichmentError(Exception):
    pass


@dataclass
class TuikRecord:
    admin_code: str
    population: int
    year: int


@dataclass
class WikidataRecord:
    osm_id: int | None
    wikidata_id: str
    name_en: str | None
    population: int | None


def load_tuik(csv_path: Path, default_year: int) -> dict[str, TuikRecord]:
    """Parse a TÜİK ADNKS CSV keyed by admin code.

    Expected columns (case-insensitive): ``code``/``kod``/``plaka``, ``population``/``nufus``,
    optional ``year``/``yil``. Extra columns are ignored.
    """
    if not csv_path.is_file():
        raise EnrichmentError(f"TÜİK CSV not found: {csv_path}")

    out: dict[str, TuikRecord] = {}
    with csv_path.open("r", encoding="utf-8-sig", newline="") as fh:
        reader = csv.DictReader(fh)
        fields = {(f or "").strip().lower(): f for f in (reader.fieldnames or [])}
        code_col = _first(fields, ("code", "kod", "plaka", "admin_code"))
        pop_col = _first(fields, ("population", "nufus", "nüfus", "total"))
        year_col = _first(fields, ("year", "yil", "yıl"))
        if not code_col or not pop_col:
            raise EnrichmentError(
                f"{csv_path.name}: need a code column and a population column; "
                f"found {reader.fieldnames}"
            )
        for row in reader:
            code = str(row[code_col]).strip().lstrip("0") or "0"
            pop = _int(row[pop_col])
            if pop is None:
                continue
            year = _int(row[year_col]) if year_col else None
            out[code] = TuikRecord(code, pop, year or default_year)
    return out


def load_wikidata(json_path: Path) -> list[WikidataRecord]:
    """Parse the output of the Wikidata SPARQL query (see tools/README.md).

    Accepts either the raw SPARQL JSON (``results.bindings``) or a pre-flattened list of
    ``{osm_id, wikidata_id, name_en, population}`` objects.
    """
    if not json_path.is_file():
        raise EnrichmentError(f"Wikidata JSON not found: {json_path}")

    data = json.loads(json_path.read_text(encoding="utf-8"))
    rows = data.get("results", {}).get("bindings") if isinstance(data, dict) else data
    if rows is None:
        rows = data

    out: list[WikidataRecord] = []
    for row in rows:
        if "item" in row and isinstance(row["item"], dict):  # raw SPARQL binding
            qid = row["item"]["value"].rsplit("/", 1)[-1]
            osm = _int(row.get("osmId", {}).get("value"))
            name_en = row.get("nameEn", {}).get("value")
            pop = _int(row.get("population", {}).get("value"))
        else:  # flattened
            qid = str(row["wikidata_id"])
            osm = _int(row.get("osm_id"))
            name_en = row.get("name_en")
            pop = _int(row.get("population"))
        out.append(WikidataRecord(osm, qid, name_en, pop))
    return out


def _first(fields: dict[str, str], candidates: tuple[str, ...]) -> str | None:
    for c in candidates:
        if c in fields:
            return fields[c]
    return None


def _int(value) -> int | None:
    if value is None:
        return None
    try:
        return int(round(float(str(value).replace(",", "").replace(" ", ""))))
    except (TypeError, ValueError):
        return None

"""Live Wikidata enrichment (spec K7).

Every admin unit carries an OSM ``wikidata=*`` tag. Wikidata is CC0 (no attribution
burden) and one ``wbgetentities`` call returns 50 entities at once, each with:

* **P1082** population — the value with the most recent point-in-time qualifier
* **sitelinks** — the ``trwiki`` / ``enwiki`` article titles (fed to the summary fetch)
* the English label — fills ``name_en`` when OSM has no ``name:en``

v1 Turkey would ideally take population from TÜİK (spec K7), but absent a TÜİK CSV the
Wikidata value is used and marked ``population_src='wikidata'``.

Raw responses are cached to disk so re-runs need no network and stay deterministic.
"""

from __future__ import annotations

import json
import time
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path

_API = "https://www.wikidata.org/w/api.php"
_BATCH = 50


@dataclass
class WikidataEntity:
    qid: str
    population: int | None = None
    population_year: int | None = None
    label_en: str | None = None
    sitelinks: dict[str, str] = field(default_factory=dict)  # lang -> article title


def fetch(
    qids: list[str],
    languages: list[str],
    cache_path: Path,
    *,
    offline: bool = False,
    delay: float = 0.2,
) -> dict[str, WikidataEntity]:
    """Return ``{qid: WikidataEntity}`` for every resolvable id.

    Uses ``cache_path`` (a JSON blob of raw entity dicts) first; only ids not cached are
    fetched. With ``offline=True`` nothing is fetched — the cache is used as-is.
    """
    wanted = sorted({q for q in qids if q and q.startswith("Q")})
    cache = _load_cache(cache_path)

    missing = [q for q in wanted if q not in cache]
    if missing and not offline:
        for i in range(0, len(missing), _BATCH):
            batch = missing[i : i + _BATCH]
            for qid, raw in _fetch_batch(batch).items():
                cache[qid] = raw
            if delay:
                time.sleep(delay)
        _save_cache(cache_path, cache)

    out: dict[str, WikidataEntity] = {}
    for qid in wanted:
        raw = cache.get(qid)
        if raw is None:
            continue
        out[qid] = _parse_entity(qid, raw, languages)
    return out


# --------------------------------------------------------------------------- network

def _fetch_batch(qids: list[str]) -> dict[str, dict]:
    params = urllib.parse.urlencode(
        {
            "action": "wbgetentities",
            "ids": "|".join(qids),
            "props": "claims|sitelinks|labels",
            "languages": "en",
            "sitefilter": "trwiki|enwiki",
            "format": "json",
        }
    )
    req = urllib.request.Request(
        f"{_API}?{params}", headers={"User-Agent": "Waymark-pack/1.0 (offline travel app)"}
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except Exception as exc:  # noqa: BLE001 - transient / offline, skip this batch
        print(f"  wikidata: batch failed ({exc}); continuing")
        return {}
    return data.get("entities", {})


# --------------------------------------------------------------------------- parsing

def _parse_entity(qid: str, raw: dict, languages: list[str]) -> WikidataEntity:
    entity = WikidataEntity(qid=qid)

    label = raw.get("labels", {}).get("en", {}).get("value")
    if label:
        entity.label_en = label

    for lang in languages:
        site = f"{lang}wiki"
        title = raw.get("sitelinks", {}).get(site, {}).get("title")
        if title:
            entity.sitelinks[lang] = title

    pop, year = _best_population(raw.get("claims", {}).get("P1082", []))
    entity.population = pop
    entity.population_year = year
    return entity


def _best_population(claims: list[dict]) -> tuple[int | None, int | None]:
    """The population claim with the newest ``point in time`` (P585) qualifier."""
    best_value: int | None = None
    best_year: int | None = None
    for claim in claims:
        try:
            amount = claim["mainsnak"]["datavalue"]["value"]["amount"]
            value = int(round(float(amount.lstrip("+"))))
        except (KeyError, TypeError, ValueError):
            continue
        year = None
        for q in claim.get("qualifiers", {}).get("P585", []):
            try:
                year = int(q["datavalue"]["value"]["time"][1:5])
            except (KeyError, TypeError, ValueError):
                year = None
        if best_year is None or (year is not None and year > best_year):
            best_value, best_year = value, year
    return best_value, best_year


# --------------------------------------------------------------------------- cache

def _load_cache(path: Path) -> dict[str, dict]:
    if path.is_file():
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            return {}
    return {}


def _save_cache(path: Path, cache: dict[str, dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(cache, ensure_ascii=False, sort_keys=True, separators=(",", ":")),
        encoding="utf-8",
    )

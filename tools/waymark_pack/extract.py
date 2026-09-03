"""OSM extraction via the ``osmium`` CLI (spec 5.2 step 1).

Pulls ``admin_level`` 4/6 boundary relations and ``place=village|town|hamlet|suburb``
nodes out of a ``.osm.pbf`` extract. The heavy geometry assembly (relation -> rings) is
delegated to ``osmium export`` producing GeoJSONSeq, which the pipeline then reads.

This module intentionally shells out rather than binding pyosmium's C++ area builder:
the CLI is already a dependency, its area handling is battle-tested, and the boundary
between "raw OSM" and "our model" stays a file we can inspect.

Real inputs are large (~614 MB) and not in the repo. Absent tooling or input, callers
should fall back to ``--fixture``. See ``tools/README.md``.
"""

from __future__ import annotations

import json
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path

from .model import RawAdminUnit, RawSettlement
from .polygon import Ring

PLACE_KINDS = ("village", "town", "hamlet", "suburb")


class ExtractionError(Exception):
    """Raised when osmium is missing, the input is absent, or a subprocess fails."""


@dataclass
class ExtractInputs:
    osm_pbf: Path
    work_dir: Path
    admin_levels: tuple[int, ...]


def check_tooling() -> str:
    """Return the path to the osmium binary or raise with an actionable message."""
    osmium = shutil.which("osmium")
    if osmium is None:
        raise ExtractionError(
            "osmium CLI not found. Install it (`brew install osmium-tool`) "
            "or run build_pack.py with --fixture."
        )
    return osmium


def run(inputs: ExtractInputs) -> tuple[list[RawAdminUnit], list[RawSettlement]]:
    """Extract boundary relations and place nodes from the PBF.

    Steps:
      1. ``osmium tags-filter`` -> a small PBF with only the objects we care about.
      2. ``osmium export`` -> GeoJSONSeq with assembled geometries.
      3. parse the GeoJSON features into the raw model.
    """
    osmium = check_tooling()
    if not inputs.osm_pbf.is_file():
        raise ExtractionError(
            f"OSM extract not found: {inputs.osm_pbf}\n"
            "Download turkey-latest.osm.pbf from https://download.geofabrik.de/europe/turkey.html "
            "into tools/data/, or run with --fixture."
        )

    inputs.work_dir.mkdir(parents=True, exist_ok=True)
    filtered = inputs.work_dir / "filtered.osm.pbf"
    geojson = inputs.work_dir / "features.geojsonseq"

    level_expr = ",".join(f"admin_level={lvl}" for lvl in inputs.admin_levels)
    place_expr = ",".join(f"place={kind}" for kind in PLACE_KINDS)

    _run_osmium(
        osmium,
        ["tags-filter", str(inputs.osm_pbf), f"r/{level_expr}", f"n/{place_expr}",
         "-o", str(filtered), "--overwrite"],
    )
    _run_osmium(
        osmium,
        ["export", str(filtered), "-o", str(geojson), "--overwrite",
         "--geometry-types=polygon,point", "-f", "geojsonseq",
         # osmium omits object ids from geojsonseq unless asked; `type_id` yields a
         # stable top-level "id" like "a2477847" (a = assembled area).
         "--add-unique-id=type_id"],
    )

    return _parse_geojsonseq(geojson, inputs.admin_levels)


def _run_osmium(osmium: str, args: list[str]) -> None:
    proc = subprocess.run([osmium, *args], capture_output=True, text=True)
    if proc.returncode != 0:
        raise ExtractionError(
            f"osmium {args[0]} failed ({proc.returncode}):\n{proc.stderr.strip()}"
        )


def _parse_geojsonseq(
    path: Path, admin_levels: tuple[int, ...]
) -> tuple[list[RawAdminUnit], list[RawSettlement]]:
    admin: list[RawAdminUnit] = []
    settlements: list[RawSettlement] = []

    with path.open("r", encoding="utf-8") as fh:
        for line in fh:
            line = line.strip().lstrip("\x1e")  # RS char in geojsonseq
            if not line:
                continue
            feature = json.loads(line)
            props = feature.get("properties", {})
            geom = feature.get("geometry") or {}
            gtype = geom.get("type")
            osm_id = _osm_id(feature, props)

            if gtype in ("Polygon", "MultiPolygon"):
                level = _int_or_none(props.get("admin_level"))
                if level is None or level not in admin_levels:
                    continue
                # Islands and other non-boundary areas sometimes carry an admin_level
                # tag. A real administrative unit is boundary=administrative with a name.
                if props.get("boundary") != "administrative":
                    continue
                if not str(props.get("name") or "").strip():
                    continue
                if props.get("natural") or props.get("place") in ("island", "islet"):
                    continue
                admin.append(
                    RawAdminUnit(
                        osm_id=osm_id,
                        admin_level=level,
                        tags=_string_tags(props),
                        rings=_rings_from_geojson(geom),
                    )
                )
            elif gtype == "Point":
                place = props.get("place")
                if place not in PLACE_KINDS:
                    continue
                lon, lat = geom["coordinates"][:2]
                settlements.append(
                    RawSettlement(
                        osm_id=osm_id,
                        place=place,
                        tags=_string_tags(props),
                        lat=float(lat),
                        lon=float(lon),
                    )
                )

    return admin, settlements


def _rings_from_geojson(geom: dict) -> list[Ring]:
    rings: list[Ring] = []
    polys = (
        [geom["coordinates"]]
        if geom["type"] == "Polygon"
        else geom["coordinates"]
    )
    for poly in polys:
        for i, ring_coords in enumerate(poly):
            pts = [(float(x), float(y)) for x, y in ring_coords]
            rings.append(Ring(is_hole=(i > 0), points=pts))
    return rings


def _string_tags(props: dict) -> dict[str, str]:
    return {k: str(v) for k, v in props.items() if v is not None}


def _osm_id(feature: dict, props: dict) -> int:
    # `osmium export --add-unique-id=type_id` puts a stable id at the top level, e.g.
    # "a2477847" (assembled area), "r123", "w123", "n123". The prefix letter is dropped;
    # the number is unique and stable across runs, which is all the pipeline needs.
    for val in (feature.get("id"), feature.get("@id"), props.get("@id"),
                props.get("id"), props.get("osm_id")):
        parsed = _int_or_none(val)
        if parsed is not None:
            return parsed
    return 0


def _int_or_none(value) -> int | None:
    try:
        return int(str(value).lstrip("arnw"))  # tolerate "a12345" / "r12345" style ids
    except (TypeError, ValueError):
        return None

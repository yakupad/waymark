"""Polygon binary format (spec 5.4).

This byte layout is a CONTRACT shared with the Swift side: ``PolygonDecoder`` in the
``GeoData`` package (phase F2) decodes exactly what :func:`encode` produces here. Any
change to this file must be mirrored there.

Layout (little-endian, fixed width)::

    uint8   version        (= 1)
    uint16  ringCount
    per ring:
        uint8   isHole     (0 = outer ring, 1 = inner ring / enclave)
        uint32  pointCount
        pointCount × { int32 lon_e6 ; int32 lat_e6 }   # degrees × 1_000_000

``int32 × 1e6`` gives ~11 cm resolution, far below the 100 m simplification tolerance.
Integers (not float32) are used because the behaviour is platform-independent and
deterministic.

Inner-ring support is mandatory: Turkey has enclave cases (an area belonging to one
district fully surrounded by another). Ray casting must account for these.
"""

from __future__ import annotations

import struct
from dataclasses import dataclass

from . import POLYGON_FORMAT_VERSION

_E6 = 1_000_000
_HEADER = struct.Struct("<BH")        # version, ringCount
_RING_HEADER = struct.Struct("<BI")   # isHole, pointCount
_POINT = struct.Struct("<ii")         # lon_e6, lat_e6

# int32 range — a coordinate outside this cannot be represented.
_INT32_MIN = -(2**31)
_INT32_MAX = 2**31 - 1


class PolygonError(Exception):
    """Base class for polygon encode/decode failures."""


class EncodeError(PolygonError):
    """Raised when input geometry cannot be represented in the binary format."""


class DecodeError(PolygonError):
    """Raised when a blob is malformed. Never let a bad blob crash the reader."""


@dataclass(frozen=True)
class Ring:
    """A single closed ring. ``points`` is a list of ``(lon, lat)`` degree pairs."""

    is_hole: bool
    points: list[tuple[float, float]]


def encode(rings: list[Ring]) -> bytes:
    """Serialise ``rings`` to the spec 5.4 binary format.

    The first ring is expected to be the outer boundary (``is_hole=False``); any
    ``is_hole=True`` rings are enclaves. Coordinates are quantised to 1e-6 degrees.
    """
    if len(rings) > 0xFFFF:
        raise EncodeError(f"ringCount {len(rings)} exceeds uint16 max (65535)")

    out = bytearray()
    out += _HEADER.pack(POLYGON_FORMAT_VERSION, len(rings))

    for i, ring in enumerate(rings):
        pts = ring.points
        if len(pts) < 3:
            raise EncodeError(f"ring {i} has {len(pts)} points; a ring needs at least 3")
        if len(pts) > 0xFFFFFFFF:
            raise EncodeError(f"ring {i} pointCount exceeds uint32 max")

        out += _RING_HEADER.pack(1 if ring.is_hole else 0, len(pts))
        for lon, lat in pts:
            lon_e6 = _quantise(lon, i, "lon")
            lat_e6 = _quantise(lat, i, "lat")
            out += _POINT.pack(lon_e6, lat_e6)

    return bytes(out)


def decode(blob: bytes | bytearray | memoryview) -> list[Ring]:
    """Parse a spec 5.4 blob. Raises :class:`DecodeError` on any malformation.

    Guaranteed not to raise anything other than ``DecodeError`` for bad input
    (spec 12.1: corrupt blob, zero rings, single-point ring must all be handled).
    """
    mv = memoryview(bytes(blob))
    if len(mv) < _HEADER.size:
        raise DecodeError(f"blob too short for header: {len(mv)} bytes")

    version, ring_count = _HEADER.unpack_from(mv, 0)
    if version != POLYGON_FORMAT_VERSION:
        raise DecodeError(f"unsupported polygon format version {version}")

    offset = _HEADER.size
    rings: list[Ring] = []

    for r in range(ring_count):
        if offset + _RING_HEADER.size > len(mv):
            raise DecodeError(f"truncated ring header at ring {r}")
        is_hole, point_count = _RING_HEADER.unpack_from(mv, offset)
        offset += _RING_HEADER.size

        if is_hole not in (0, 1):
            raise DecodeError(f"ring {r} isHole is {is_hole}, expected 0 or 1")
        if point_count < 3:
            raise DecodeError(f"ring {r} has pointCount {point_count}; minimum is 3")

        end = offset + point_count * _POINT.size
        if end > len(mv):
            raise DecodeError(
                f"ring {r} declares {point_count} points but blob ends early"
            )

        points: list[tuple[float, float]] = []
        for _ in range(point_count):
            lon_e6, lat_e6 = _POINT.unpack_from(mv, offset)
            offset += _POINT.size
            points.append((lon_e6 / _E6, lat_e6 / _E6))

        rings.append(Ring(is_hole=bool(is_hole), points=points))

    if offset != len(mv):
        raise DecodeError(f"{len(mv) - offset} trailing bytes after {ring_count} rings")

    return rings


def _quantise(deg: float, ring_index: int, axis: str) -> int:
    scaled = round(deg * _E6)
    if scaled < _INT32_MIN or scaled > _INT32_MAX:
        raise EncodeError(
            f"ring {ring_index} {axis} {deg} out of int32 range after scaling"
        )
    return scaled


def rings_from_shapely(geom) -> list[Ring]:
    """Convert a shapely Polygon or MultiPolygon into ordered :class:`Ring` list.

    Exterior rings first (``is_hole=False``), interiors after (``is_hole=True``).
    Imported lazily so the rest of the pipeline works without shapely installed.
    """
    try:
        from shapely.geometry import MultiPolygon, Polygon
    except ImportError as exc:  # pragma: no cover - exercised only without shapely
        raise EncodeError("shapely is required for rings_from_shapely()") from exc

    polys: list = []
    if isinstance(geom, Polygon):
        polys = [geom]
    elif isinstance(geom, MultiPolygon):
        polys = list(geom.geoms)
    else:
        raise EncodeError(f"expected Polygon/MultiPolygon, got {type(geom).__name__}")

    rings: list[Ring] = []
    for poly in polys:
        rings.append(Ring(is_hole=False, points=list(poly.exterior.coords)))
        for interior in poly.interiors:
            rings.append(Ring(is_hole=True, points=list(interior.coords)))
    return rings

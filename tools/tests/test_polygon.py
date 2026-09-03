"""Polygon binary format — spec 5.4, test scenarios from spec 12.1.

This byte layout is shared with the Swift PolygonDecoder (F2). If these tests change,
the Swift decoder tests must change with them.
"""

import struct

import pytest

from waymark_pack.polygon import (
    DecodeError,
    EncodeError,
    Ring,
    decode,
    encode,
)


def _square(cx=0.0, cy=0.0, h=1.0, is_hole=False):
    return Ring(
        is_hole=is_hole,
        points=[
            (cx - h, cy - h), (cx + h, cy - h), (cx + h, cy + h),
            (cx - h, cy + h), (cx - h, cy - h),
        ],
    )


def test_round_trip_single_ring():
    rings = [_square()]
    out = decode(encode(rings))
    assert len(out) == 1
    assert out[0].is_hole is False
    assert out[0].points[0] == pytest.approx((-1.0, -1.0))
    assert out[0].points == pytest.approx(rings[0].points)


def test_round_trip_with_inner_ring_enclave():
    rings = [_square(h=1.0), _square(h=0.2, is_hole=True)]
    out = decode(encode(rings))
    assert [r.is_hole for r in out] == [False, True]
    assert out[1].points == pytest.approx(rings[1].points)


def test_quantisation_is_1e6():
    rings = [Ring(False, [(1.2345678, 2.0), (3.0, 4.0), (5.0, 6.0), (1.2345678, 2.0)])]
    out = decode(encode(rings))
    # 1.2345678 -> 1234568 / 1e6 -> 1.234568
    assert out[0].points[0][0] == pytest.approx(1.234568, abs=1e-9)


def test_header_is_little_endian_version_1():
    blob = encode([_square()])
    version, ring_count = struct.unpack_from("<BH", blob, 0)
    assert version == 1
    assert ring_count == 1


def test_decode_rejects_empty_blob():
    with pytest.raises(DecodeError):
        decode(b"")


def test_decode_rejects_truncated_blob():
    blob = encode([_square()])
    with pytest.raises(DecodeError):
        decode(blob[:-4])


def test_decode_rejects_bad_version():
    blob = bytearray(encode([_square()]))
    blob[0] = 9
    with pytest.raises(DecodeError):
        decode(bytes(blob))


def test_decode_rejects_trailing_bytes():
    with pytest.raises(DecodeError):
        decode(encode([_square()]) + b"\x00\x00")


def test_decode_zero_rings_is_valid_and_empty():
    blob = struct.pack("<BH", 1, 0)
    assert decode(blob) == []


def test_decode_rejects_single_point_ring():
    # version=1, ringCount=1, isHole=0, pointCount=1, one point
    blob = struct.pack("<BH", 1, 1) + struct.pack("<BI", 0, 1) + struct.pack("<ii", 0, 0)
    with pytest.raises(DecodeError):
        decode(blob)


def test_decode_rejects_bad_is_hole_flag():
    blob = struct.pack("<BH", 1, 1) + struct.pack("<BI", 5, 3) + struct.pack("<ii", 0, 0) * 3
    with pytest.raises(DecodeError):
        decode(blob)


def test_encode_rejects_ring_under_three_points():
    with pytest.raises(EncodeError):
        encode([Ring(False, [(0.0, 0.0), (1.0, 1.0)])])


def test_encode_rejects_coordinate_out_of_int32_range():
    with pytest.raises(EncodeError):
        encode([Ring(False, [(3000.0, 0.0), (1.0, 1.0), (2.0, 2.0), (3000.0, 0.0)])])


def test_decode_never_raises_non_decode_error_on_fuzzed_input():
    good = encode([_square(), _square(h=0.3, is_hole=True)])
    for cut in range(len(good) + 4):
        try:
            decode(good[:cut])
        except DecodeError:
            pass
        except Exception as exc:  # noqa: BLE001
            pytest.fail(f"decode raised {type(exc).__name__} at cut={cut}: {exc}")

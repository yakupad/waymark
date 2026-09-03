//  PolygonDecoder.swift
//  GeoData
//
//  Decoder for the polygon binary format (spec 5.4). This is a byte-for-byte contract
//  with `tools/waymark_pack/polygon.py` on the pipeline side: whatever `encode()` there
//  writes, this reads. Any change to the layout must be mirrored in both files.
//
//  Layout (little-endian, fixed width):
//
//      uint8   version        (= 1)
//      uint16  ringCount
//      per ring:
//          uint8   isHole     (0 = outer ring, 1 = inner ring / enclave)
//          uint32  pointCount
//          pointCount × { int32 lon_e6 ; int32 lat_e6 }   // degrees × 1_000_000
//
//  The reader never traps on bad input (spec 12.1): a corrupt blob, zero rings, or a
//  single-point ring all surface as a thrown `PolygonDecodeError`.

import Foundation

/// One closed ring. `points` are decoded to degrees. The first ring of a polygon is its
/// outer boundary; `isHole` rings are enclaves fully contained by an outer ring.
public struct PolygonRing: Hashable, Sendable {
    public let isHole: Bool
    public let points: [Coordinate]

    public init(isHole: Bool, points: [Coordinate]) {
        self.isHole = isHole
        self.points = points
    }
}

public enum PolygonDecodeError: Error, Hashable, Sendable {
    case blobTooShort(expected: Int, got: Int)
    case unsupportedVersion(UInt8)
    case truncatedRingHeader(ringIndex: Int)
    case invalidHoleFlag(ringIndex: Int, value: UInt8)
    case ringTooFewPoints(ringIndex: Int, count: UInt32)
    case truncatedPoints(ringIndex: Int, declared: UInt32)
    case trailingBytes(Int)
}

public enum PolygonDecoder {
    /// Must equal `POLYGON_FORMAT_VERSION` in `tools/waymark_pack/__init__.py`.
    public static let formatVersion: UInt8 = 1

    private static let e6 = 1_000_000.0
    private static let headerSize = 3      // version + ringCount
    private static let ringHeaderSize = 5  // isHole + pointCount
    private static let pointSize = 8       // lon_e6 + lat_e6

    /// Parse a spec 5.4 blob. Zero-copy: reads straight out of the `Data` buffer.
    /// - Throws: `PolygonDecodeError` — and nothing else — for any malformed input.
    public static func decode(_ blob: Data) throws -> [PolygonRing] {
        try blob.withUnsafeBytes { raw -> [PolygonRing] in
            let count = raw.count
            var cursor = 0

            func remaining() -> Int { count - cursor }
            func loadU8() -> UInt8 {
                defer { cursor += 1 }
                return raw.loadUnaligned(fromByteOffset: cursor, as: UInt8.self)
            }
            func loadU16() -> UInt16 {
                defer { cursor += 2 }
                return UInt16(littleEndian: raw.loadUnaligned(fromByteOffset: cursor, as: UInt16.self))
            }
            func loadU32() -> UInt32 {
                defer { cursor += 4 }
                return UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: cursor, as: UInt32.self))
            }
            func loadI32() -> Int32 {
                defer { cursor += 4 }
                return Int32(littleEndian: raw.loadUnaligned(fromByteOffset: cursor, as: Int32.self))
            }

            guard remaining() >= headerSize else {
                throw PolygonDecodeError.blobTooShort(expected: headerSize, got: count)
            }
            let version = loadU8()
            guard version == formatVersion else {
                throw PolygonDecodeError.unsupportedVersion(version)
            }
            let ringCount = Int(loadU16())

            var rings: [PolygonRing] = []
            rings.reserveCapacity(ringCount)

            for r in 0..<ringCount {
                guard remaining() >= ringHeaderSize else {
                    throw PolygonDecodeError.truncatedRingHeader(ringIndex: r)
                }
                let holeFlag = loadU8()
                guard holeFlag == 0 || holeFlag == 1 else {
                    throw PolygonDecodeError.invalidHoleFlag(ringIndex: r, value: holeFlag)
                }
                let pointCount = loadU32()
                guard pointCount >= 3 else {
                    throw PolygonDecodeError.ringTooFewPoints(ringIndex: r, count: pointCount)
                }
                // Int(pointCount) * pointSize cannot overflow Int on a 64-bit platform;
                // uint32 max * 8 ≈ 3.4e10, well inside Int.max.
                guard remaining() >= Int(pointCount) * pointSize else {
                    throw PolygonDecodeError.truncatedPoints(ringIndex: r, declared: pointCount)
                }

                var points: [Coordinate] = []
                points.reserveCapacity(Int(pointCount))
                for _ in 0..<pointCount {
                    let lon = Double(loadI32()) / e6
                    let lat = Double(loadI32()) / e6
                    points.append(Coordinate(latitude: lat, longitude: lon))
                }
                rings.append(PolygonRing(isHole: holeFlag == 1, points: points))
            }

            guard cursor == count else {
                throw PolygonDecodeError.trailingBytes(count - cursor)
            }
            return rings
        }
    }
}

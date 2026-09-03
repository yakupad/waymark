//  RouteBlob.swift
//  TripKit
//
//  Binary serialisation of a `RouteTrace` (spec 7.7 step 4): the spec 5.4 `int32 × 1e6`
//  coordinate encoding, extended with segment boundaries, as a single `Data` blob. One
//  `Trip` stores one of these — never a model object per point (spec 7.7 / §9).
//
//  Layout (little-endian):
//
//      uint8   version          (= 1)
//      uint16  segmentCount
//      per segment:
//          int64   startedAtMillis   (Unix epoch milliseconds)
//          int64   endedAtMillis
//          uint32  pointCount
//          pointCount × { int32 lon_e6 ; int32 lat_e6 }   // same order as spec 5.4
//
//  Decoding never traps: a corrupt blob throws `RouteBlobError`.

import Foundation
import GeoData

public enum RouteBlobError: Error, Equatable, Sendable {
    case blobTooShort(expected: Int, got: Int)
    case unsupportedVersion(UInt8)
    case truncatedSegmentHeader(segmentIndex: Int)
    case truncatedPoints(segmentIndex: Int, declared: UInt32)
    case trailingBytes(Int)
}

public enum RouteBlob {

    public static let formatVersion: UInt8 = 1
    private static let e6 = 1_000_000.0
    private static let headerSize = 3
    private static let segmentHeaderSize = 20   // 8 + 8 + 4
    private static let pointSize = 8

    // MARK: Encode

    public static func encode(_ trace: RouteTrace) -> Data {
        var data = Data()
        data.reserveCapacity(headerSize + trace.segments.count * segmentHeaderSize + trace.pointCount * pointSize)
        append(&data, formatVersion)
        append(&data, UInt16(min(trace.segments.count, Int(UInt16.max))))

        for segment in trace.segments.prefix(Int(UInt16.max)) {
            append(&data, millis(segment.startedAt))
            append(&data, millis(segment.endedAt))
            append(&data, UInt32(segment.points.count))
            for p in segment.points {
                append(&data, Int32(( p.longitude * e6).rounded()))
                append(&data, Int32(( p.latitude * e6).rounded()))
            }
        }
        return data
    }

    // MARK: Decode

    public static func decode(_ blob: Data) throws -> RouteTrace {
        try blob.withUnsafeBytes { raw -> RouteTrace in
            let count = raw.count
            var cursor = 0
            func remaining() -> Int { count - cursor }
            func u8() -> UInt8 { defer { cursor += 1 }; return raw.loadUnaligned(fromByteOffset: cursor, as: UInt8.self) }
            func u16() -> UInt16 { defer { cursor += 2 }; return UInt16(littleEndian: raw.loadUnaligned(fromByteOffset: cursor, as: UInt16.self)) }
            func u32() -> UInt32 { defer { cursor += 4 }; return UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: cursor, as: UInt32.self)) }
            func i32() -> Int32 { defer { cursor += 4 }; return Int32(littleEndian: raw.loadUnaligned(fromByteOffset: cursor, as: Int32.self)) }
            func i64() -> Int64 { defer { cursor += 8 }; return Int64(littleEndian: raw.loadUnaligned(fromByteOffset: cursor, as: Int64.self)) }

            guard remaining() >= headerSize else {
                throw RouteBlobError.blobTooShort(expected: headerSize, got: count)
            }
            let version = u8()
            guard version == formatVersion else {
                throw RouteBlobError.unsupportedVersion(version)
            }
            let segmentCount = Int(u16())

            var segments: [RouteSegment] = []
            segments.reserveCapacity(segmentCount)

            for s in 0..<segmentCount {
                guard remaining() >= segmentHeaderSize else {
                    throw RouteBlobError.truncatedSegmentHeader(segmentIndex: s)
                }
                let startedAt = date(fromMillis: i64())
                let endedAt = date(fromMillis: i64())
                let pointCount = u32()
                guard remaining() >= Int(pointCount) * pointSize else {
                    throw RouteBlobError.truncatedPoints(segmentIndex: s, declared: pointCount)
                }
                var points: [Coordinate] = []
                points.reserveCapacity(Int(pointCount))
                for _ in 0..<pointCount {
                    let lon = Double(i32()) / e6
                    let lat = Double(i32()) / e6
                    points.append(Coordinate(latitude: lat, longitude: lon))
                }
                segments.append(RouteSegment(points: points, startedAt: startedAt, endedAt: endedAt))
            }

            guard cursor == count else {
                throw RouteBlobError.trailingBytes(count - cursor)
            }
            return RouteTrace(segments: segments)
        }
    }

    // MARK: -

    private static func append<T: FixedWidthInteger>(_ data: inout Data, _ value: T) {
        var le = value.littleEndian
        withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
    }

    private static func millis(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1000).rounded())
    }

    private static func date(fromMillis millis: Int64) -> Date {
        Date(timeIntervalSince1970: Double(millis) / 1000)
    }
}

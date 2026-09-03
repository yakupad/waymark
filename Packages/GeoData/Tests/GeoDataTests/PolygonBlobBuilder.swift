//  PolygonBlobBuilder.swift
//  GeoDataTests
//
//  Hand-rolls spec 5.4 blobs so decoder tests can craft both valid and deliberately
//  broken inputs. Mirrors `tools/waymark_pack/polygon.py::encode`.

import Foundation

struct BlobRing {
    var isHole: Bool
    var points: [(lon: Double, lat: Double)]
}

enum PolygonBlobBuilder {
    /// Build a well-formed blob. `overrideRingCount` / `overridePointCounts` let a test
    /// lie in the headers to simulate corruption.
    static func make(
        _ rings: [BlobRing],
        version: UInt8 = 1,
        overrideRingCount: UInt16? = nil
    ) -> Data {
        var data = Data()
        data.append(version)
        appendLE(&data, overrideRingCount ?? UInt16(rings.count))
        for ring in rings {
            data.append(ring.isHole ? 1 : 0)
            appendLE(&data, UInt32(ring.points.count))
            for p in ring.points {
                appendLE(&data, Int32((p.lon * 1_000_000).rounded()))
                appendLE(&data, Int32((p.lat * 1_000_000).rounded()))
            }
        }
        return data
    }

    /// A closed square ring centred at (cx, cy) with the given half-width, in degrees.
    static func square(cx: Double, cy: Double, half: Double, isHole: Bool = false) -> BlobRing {
        BlobRing(isHole: isHole, points: [
            (cx - half, cy - half),
            (cx + half, cy - half),
            (cx + half, cy + half),
            (cx - half, cy + half),
            (cx - half, cy - half),
        ])
    }

    private static func appendLE<T: FixedWidthInteger>(_ data: inout Data, _ value: T) {
        var le = value.littleEndian
        withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
    }
}

//  PointInPolygon.swift
//  GeoData
//
//  Ray-casting point-in-polygon with inner-ring (enclave) support (spec 5.4, 7.6, 12.1).
//
//  A polygon blob is a flat list of rings. Membership is: the point lies inside at least
//  one outer ring AND inside none of the hole rings (spec 7.6 step 3 — "ray casting, iç
//  ringler hariç tutularak"). Turkey has genuine enclaves — a district area fully
//  enclosed by another district — so holes must subtract.
//
//  Turkey spans neither a pole nor the antimeridian, so planar ray casting in degree
//  space is correct here (spec 12.1).

import Foundation

public enum PointInPolygon {

    /// True if `point` is inside the polygon described by `rings`.
    public static func contains(_ point: Coordinate, rings: [PolygonRing]) -> Bool {
        var insideAnyOuter = false
        for ring in rings where !ring.isHole {
            if rayCast(point, ring.points) {
                insideAnyOuter = true
                break
            }
        }
        guard insideAnyOuter else { return false }

        for ring in rings where ring.isHole {
            if rayCast(point, ring.points) {
                return false
            }
        }
        return true
    }

    /// Convenience: decode then test. Propagates `PolygonDecodeError`.
    public static func contains(_ point: Coordinate, blob: Data) throws -> Bool {
        contains(point, rings: try PolygonDecoder.decode(blob))
    }

    /// Standard even-odd ray cast against a single ring. Works whether or not the ring
    /// is explicitly closed (first point repeated). A point exactly on an edge is
    /// reported consistently but its exact classification is not contractual — callers
    /// rely on hysteresis (spec 7.5), not on boundary precision.
    static func rayCast(_ p: Coordinate, _ ring: [Coordinate]) -> Bool {
        guard ring.count >= 3 else { return false }

        let x = p.longitude
        let y = p.latitude
        var inside = false

        var j = ring.count - 1
        for i in 0..<ring.count {
            let xi = ring[i].longitude, yi = ring[i].latitude
            let xj = ring[j].longitude, yj = ring[j].latitude

            let straddles = (yi > y) != (yj > y)
            if straddles {
                let intersectX = (xj - xi) * (y - yi) / (yj - yi) + xi
                if x < intersectX {
                    inside.toggle()
                }
            }
            j = i
        }
        return inside
    }
}

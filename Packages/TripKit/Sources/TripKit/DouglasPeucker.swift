//  DouglasPeucker.swift
//  TripKit
//
//  Ramer–Douglas–Peucker line simplification (spec 7.7 step 3: 20 m tolerance). Cuts
//  the point count of a route without visibly changing its shape. First and last
//  points are always kept.
//
//  Perpendicular distance is computed in a local equirectangular projection (metres)
//  centred on the segment — accurate well past the 20 m tolerance for the short spans
//  between GPS fixes, and pole/antimeridian-free (v1 is Turkey).

import Foundation
import GeoData

public enum DouglasPeucker {

    public static func simplify(_ points: [Coordinate], toleranceMeters: Double) -> [Coordinate] {
        guard points.count > 2, toleranceMeters > 0 else { return points }
        var keep = [Bool](repeating: false, count: points.count)
        keep[0] = true
        keep[points.count - 1] = true
        simplifySlice(points, 0, points.count - 1, toleranceMeters, &keep)
        return zip(points, keep).compactMap { $1 ? $0 : nil }
    }

    private static func simplifySlice(
        _ points: [Coordinate], _ first: Int, _ last: Int,
        _ tolerance: Double, _ keep: inout [Bool]
    ) {
        guard last > first + 1 else { return }

        let a = points[first]
        let b = points[last]
        let lat0 = (a.latitude + b.latitude) / 2 * .pi / 180
        let mPerDegLat = 111_132.0
        let mPerDegLon = 111_320.0 * cos(lat0)

        func project(_ c: Coordinate) -> (x: Double, y: Double) {
            (x: (c.longitude - a.longitude) * mPerDegLon,
             y: (c.latitude - a.latitude) * mPerDegLat)
        }

        let pa = project(a)
        let pb = project(b)
        let dx = pb.x - pa.x
        let dy = pb.y - pa.y
        let edgeLength = (dx * dx + dy * dy).squareRoot()

        var maxDistance = 0.0
        var maxIndex = first
        for i in (first + 1)..<last {
            let p = project(points[i])
            let distance: Double
            if edgeLength == 0 {
                distance = (p.x * p.x + p.y * p.y).squareRoot()
            } else {
                distance = abs(dy * p.x - dx * p.y + pb.x * pa.y - pb.y * pa.x) / edgeLength
            }
            if distance > maxDistance {
                maxDistance = distance
                maxIndex = i
            }
        }

        guard maxDistance > tolerance else { return }
        keep[maxIndex] = true
        simplifySlice(points, first, maxIndex, tolerance, &keep)
        simplifySlice(points, maxIndex, last, tolerance, &keep)
    }
}

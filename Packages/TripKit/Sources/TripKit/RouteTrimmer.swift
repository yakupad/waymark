//  RouteTrimmer.swift
//  TripKit
//
//  Endpoint trimming for `RouteTrace.trimmed(by:)` (spec 7.7). Walks a metre budget
//  from the front of a segment list, cutting inside an edge when the budget runs out
//  and interpolating the new endpoint. Trimming the back is the same operation on a
//  reversed list.

import Foundation
import GeoData

enum RouteTrimmer {

    /// Remove `budget` metres of polyline from the front of `segments`.
    static func trimFront(_ segments: [RouteSegment], budget: Double) -> [RouteSegment] {
        var remaining = budget

        for (index, segment) in segments.enumerated() {
            let points = segment.points

            // A degenerate 0/1-point segment carries no length. Drop it while the
            // budget is still positive, otherwise keep it and everything after.
            guard points.count >= 2 else {
                if remaining > 0 { continue }
                return Array(segments[index...])
            }

            var cutPoints: [Coordinate]?
            for i in 0..<(points.count - 1) {
                let edge = Haversine.distance(points[i], points[i + 1])
                if edge <= remaining {
                    remaining -= edge
                    continue
                }
                // Budget runs out inside this edge.
                let fraction = edge > 0 ? remaining / edge : 0
                let cut = interpolate(points[i], points[i + 1], fraction)
                cutPoints = [cut] + Array(points[(i + 1)...])
                remaining = 0
                break
            }

            if let cutPoints {
                let trimmed = RouteSegment(
                    points: cutPoints, startedAt: segment.startedAt, endedAt: segment.endedAt
                )
                return [trimmed] + Array(segments[(index + 1)...])
            }
            // Whole segment consumed; if the budget landed exactly on its end, the next
            // segment starts clean.
            if remaining <= 0 {
                return Array(segments[(index + 1)...])
            }
        }
        return []
    }

    static func reversed(_ segments: [RouteSegment]) -> [RouteSegment] {
        segments.reversed().map {
            RouteSegment(
                points: $0.points.reversed(), startedAt: $0.startedAt, endedAt: $0.endedAt
            )
        }
    }

    private static func interpolate(
        _ a: Coordinate, _ b: Coordinate, _ fraction: Double
    ) -> Coordinate {
        Coordinate(
            latitude: a.latitude + (b.latitude - a.latitude) * fraction,
            longitude: a.longitude + (b.longitude - a.longitude) * fraction
        )
    }
}

//  RouteModels.swift
//  TripKit
//
//  Route-trace value types (spec §9). A route is an array of segments; gaps (tunnels,
//  no-signal stretches) separate segments so a 30 km straight line is never drawn
//  across the Bolu tunnel (spec 7.7).

import Foundation
import GeoData

public struct RouteSegment: Sendable, Equatable {
    public let points: [Coordinate]
    public let startedAt: Date
    public let endedAt: Date

    public init(points: [Coordinate], startedAt: Date, endedAt: Date) {
        self.points = points
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    /// Summed great-circle length of the polyline, in metres.
    public var distanceMeters: Double {
        guard points.count > 1 else { return 0 }
        return zip(points, points.dropFirst()).reduce(0) { $0 + Haversine.distance($1.0, $1.1) }
    }
}

public struct RouteTrace: Sendable, Equatable {
    public let segments: [RouteSegment]

    public init(segments: [RouteSegment]) {
        self.segments = segments
    }

    public static let empty = RouteTrace(segments: [])

    public var pointCount: Int {
        segments.reduce(0) { $0 + $1.points.count }
    }

    public var isEmpty: Bool {
        pointCount == 0
    }

    public var distanceMeters: Double {
        segments.reduce(0) { $0 + $1.distanceMeters }
    }

    /// A copy with the first and last `meters` of the polyline removed — for share
    /// images, so the trip's start (home) and end are not disclosed (spec 7.7, R8).
    /// Gaps between segments are preserved. `meters <= 0` is a no-op. If the trim would
    /// consume the whole route, the result is empty (spec 12.1).
    public func trimmed(by meters: Double) -> RouteTrace {
        guard meters > 0 else { return self }
        guard distanceMeters > meters * 2 else { return .empty }

        let fromFront = RouteTrimmer.trimFront(segments, budget: meters)
        let reversed = RouteTrimmer.reversed(fromFront)
        let fromBack = RouteTrimmer.trimFront(reversed, budget: meters)
        return RouteTrace(segments: RouteTrimmer.reversed(fromBack))
    }
}

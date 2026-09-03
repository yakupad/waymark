//  RouteRecorder.swift
//  TripKit
//
//  Records the route trace during an active trip (spec 7.7). Tracking and detection are
//  separate concerns (7.7): the recorder just consumes the same filtered fixes and
//  builds a segmented polyline.
//
//  - every accepted fix is buffered in memory
//  - `add` returns `true` when `flushThreshold` fixes have accumulated since the last
//    flush, so the caller can persist the raw buffer (R4: limit loss on background kill)
//  - a gap of > 2 km or > 5 min between consecutive fixes cuts the segment (7.7)
//  - `finish` closes the open segment and Douglas-Peucker-simplifies every segment at
//    20 m (7.7 step 3)

import Foundation
import GeoData

public struct RouteRecorder {

    public struct Config: Sendable, Equatable {
        public var segmentGapDistanceMeters: Double = 2_000
        public var segmentGapInterval: TimeInterval = 300     // 5 minutes
        public var flushThreshold: Int = 200
        public var simplifyToleranceMeters: Double = 20

        public init() {}
    }

    public let config: Config

    private var closedSegments: [RouteSegment] = []
    private var currentPoints: [Coordinate] = []
    private var currentStart: Date?
    private var lastPoint: Coordinate?
    private var lastTimestamp: Date?
    private var finished = false

    private(set) public var rawPointCount = 0
    private(set) public var pointsSinceFlush = 0

    public init(config: Config = Config()) {
        self.config = config
    }

    public var isEmpty: Bool {
        closedSegments.isEmpty && currentPoints.isEmpty
    }

    /// Feed one accepted fix. Returns `true` when a disk flush is due.
    @discardableResult
    public mutating func add(_ coordinate: Coordinate, at timestamp: Date) -> Bool {
        precondition(!finished, "RouteRecorder is single-use; make a new one for the next trip")

        if let lastPoint, let lastTimestamp {
            let gapDistance = Haversine.distance(lastPoint, coordinate)
            let gapInterval = timestamp.timeIntervalSince(lastTimestamp)
            let broken = gapDistance > config.segmentGapDistanceMeters
                || gapInterval > config.segmentGapInterval
                || gapInterval < 0
            if broken {
                closeCurrentSegment(endedAt: lastTimestamp)
            }
        }

        if currentPoints.isEmpty {
            currentStart = timestamp
        }
        currentPoints.append(coordinate)
        lastPoint = coordinate
        lastTimestamp = timestamp
        rawPointCount += 1
        pointsSinceFlush += 1

        return pointsSinceFlush >= config.flushThreshold
    }

    public mutating func markFlushed() {
        pointsSinceFlush = 0
    }

    /// A snapshot of the trace so far (open segment included). Non-mutating so the UI
    /// can draw the live route without ending recording.
    public func snapshot(simplified: Bool = false) -> RouteTrace {
        var segments = closedSegments
        if !currentPoints.isEmpty, let currentStart, let lastTimestamp {
            segments.append(
                RouteSegment(points: currentPoints, startedAt: currentStart, endedAt: lastTimestamp)
            )
        }
        guard simplified else { return RouteTrace(segments: segments) }
        return RouteTrace(segments: segments.map(simplify))
    }

    /// Close the trip: finalise the open segment and simplify every segment. The
    /// recorder must not be reused afterwards (the raw buffer is considered gone).
    public mutating func finish() -> RouteTrace {
        precondition(!finished, "RouteRecorder.finish() called twice")
        if let lastTimestamp {
            closeCurrentSegment(endedAt: lastTimestamp)
        }
        finished = true
        return RouteTrace(segments: closedSegments.map(simplify))
    }

    // MARK: -

    private mutating func closeCurrentSegment(endedAt: Date) {
        guard !currentPoints.isEmpty, let currentStart else { return }
        closedSegments.append(
            RouteSegment(points: currentPoints, startedAt: currentStart, endedAt: endedAt)
        )
        currentPoints.removeAll(keepingCapacity: true)
        self.currentStart = nil
        lastPoint = nil
        lastTimestamp = nil
    }

    private func simplify(_ segment: RouteSegment) -> RouteSegment {
        RouteSegment(
            points: DouglasPeucker.simplify(
                segment.points, toleranceMeters: config.simplifyToleranceMeters
            ),
            startedAt: segment.startedAt,
            endedAt: segment.endedAt
        )
    }
}

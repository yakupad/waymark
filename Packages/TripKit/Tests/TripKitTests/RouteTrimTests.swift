//  RouteTrimTests.swift
//  TripKitTests
//
//  Spec 7.7 / 12.1: endpoint trimming for share images. Trim beyond the route length →
//  empty; negative → rejected (no-op). Inner segment gaps are preserved.

import Foundation
import Testing
import GeoData
@testable import TripKit

struct RouteTrimTests {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    /// A straight west→east segment on the equator, `count` points `stepMeters` apart.
    private func segment(fromLon: Double, count: Int, stepDegrees: Double = 0.02) -> RouteSegment {
        let pts = (0..<count).map { Coordinate(latitude: 0, longitude: fromLon + Double($0) * stepDegrees) }
        return RouteSegment(points: pts, startedAt: t0, endedAt: t0.addingTimeInterval(600))
    }

    @Test func `Trimming by zero returns the route unchanged`() {
        let trace = RouteTrace(segments: [segment(fromLon: 0, count: 10)])
        #expect(trace.trimmed(by: 0) == trace)
    }

    @Test func `A negative trim is rejected (treated as no-op)`() {
        let trace = RouteTrace(segments: [segment(fromLon: 0, count: 10)])
        #expect(trace.trimmed(by: -500) == trace)
        #expect(trace.trimmed(by: -500) == trace.trimmed(by: 0))
    }

    @Test func `Trimming more than half the route length yields an empty trace`() {
        let trace = RouteTrace(segments: [segment(fromLon: 0, count: 5)])   // ~8.9 km total
        #expect(trace.trimmed(by: trace.distanceMeters).isEmpty)
        #expect(trace.trimmed(by: trace.distanceMeters * 0.6).isEmpty)
    }

    @Test func `Trimming shortens both ends and keeps the middle`() {
        let trace = RouteTrace(segments: [segment(fromLon: 0, count: 20)])   // ~44 km
        let full = trace.distanceMeters

        let trimmed = trace.trimmed(by: 1_000)

        #expect(!trimmed.isEmpty)
        #expect(abs(trimmed.distanceMeters - (full - 2_000)) < 5)   // ~1 km off each end
        // endpoints moved inward
        #expect(trimmed.segments[0].points.first!.longitude > 0)
        #expect(trimmed.segments[0].points.last!.longitude < trace.segments[0].points.last!.longitude)
    }

    @Test func `Trimming can consume an entire leading segment`() {
        let short = segment(fromLon: 0, count: 3)          // ~4.4 km
        let long = segment(fromLon: 10, count: 30)         // ~64 km, far away (a gap)
        let trace = RouteTrace(segments: [short, long])

        let trimmed = trace.trimmed(by: 6_000)             // eats all of `short` + a bit of `long`

        #expect(trimmed.segments.count == 1)
        #expect(trimmed.segments[0].points.first!.longitude > 10)
    }

    @Test func `The gap between segments is preserved`() {
        let a = segment(fromLon: 0, count: 20)
        let b = segment(fromLon: 5, count: 20)             // large jump = a real gap
        let trace = RouteTrace(segments: [a, b])

        let trimmed = trace.trimmed(by: 500)

        #expect(trimmed.segments.count == 2)
        // the gap (first point of b minus last point of a) is unchanged in longitude
        #expect(trimmed.segments[1].points.first!.longitude == b.points.first!.longitude)
    }

    @Test func `Trimming is idempotent-ish: trim(a) then trim(b) ≈ trim(a+b)`() {
        let trace = RouteTrace(segments: [segment(fromLon: 0, count: 40)])
        let twice = trace.trimmed(by: 800).trimmed(by: 800)
        let once = trace.trimmed(by: 1_600)
        #expect(abs(twice.distanceMeters - once.distanceMeters) < 10)
    }
}

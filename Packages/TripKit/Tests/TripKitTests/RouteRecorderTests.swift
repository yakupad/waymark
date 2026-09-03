//  RouteRecorderTests.swift
//  TripKitTests
//
//  Spec 12.1: segment cutting (2 km / 5 min thresholds, consecutive gaps, gaps at the
//  start and end of a trace), plus the 200-point flush signal (7.7 step 2).

import Foundation
import Testing
import GeoData
@testable import TripKit

struct RouteRecorderTests {

    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func c(_ lat: Double, _ lon: Double) -> Coordinate {
        Coordinate(latitude: lat, longitude: lon)
    }

    @Test func `A continuous run is one segment`() {
        var r = RouteRecorder()
        for i in 0..<10 {
            r.add(c(39.0 + Double(i) * 1e-3, 32.0), at: start.addingTimeInterval(Double(i) * 30))
        }
        let trace = r.finish()
        #expect(trace.segments.count == 1)
    }

    @Test func `A > 2 km jump cuts the segment`() {
        var r = RouteRecorder()
        r.add(c(39.0, 32.0), at: start)
        r.add(c(39.0, 32.001), at: start.addingTimeInterval(30))
        // ~3 km east, only 30 s later -> distance gap
        r.add(c(39.0, 32.035), at: start.addingTimeInterval(60))
        r.add(c(39.0, 32.036), at: start.addingTimeInterval(90))
        let trace = r.finish()
        #expect(trace.segments.count == 2)
        #expect(trace.segments[0].points.count == 2)
        #expect(trace.segments[1].points.count == 2)
    }

    @Test func `A > 5 min gap cuts the segment`() {
        var r = RouteRecorder()
        r.add(c(39.0, 32.0), at: start)
        r.add(c(39.0, 32.0005), at: start.addingTimeInterval(60))
        // same spot, 6 minutes later -> time gap
        r.add(c(39.0, 32.001), at: start.addingTimeInterval(60 + 360))
        let trace = r.finish()
        #expect(trace.segments.count == 2)
    }

    @Test func `Back-to-back gaps produce isolated single-point segments`() {
        var r = RouteRecorder()
        r.add(c(39.0, 32.0), at: start)
        r.add(c(39.0, 33.0), at: start.addingTimeInterval(30))   // ~87 km jump
        r.add(c(39.0, 34.0), at: start.addingTimeInterval(60))   // another jump
        let trace = r.finish()
        #expect(trace.segments.count == 3)
        #expect(trace.segments.allSatisfy { $0.points.count == 1 })
    }

    @Test func `An out-of-order timestamp cuts the segment`() {
        var r = RouteRecorder()
        r.add(c(39.0, 32.0), at: start.addingTimeInterval(100))
        r.add(c(39.0, 32.0005), at: start.addingTimeInterval(40))
        #expect(r.finish().segments.count == 2)
    }

    @Test func `The flush signal fires exactly every flushThreshold points`() {
        var config = RouteRecorder.Config()
        config.flushThreshold = 5
        var r = RouteRecorder(config: config)
        var flushes = 0
        for i in 0..<12 {
            if r.add(c(39.0 + Double(i) * 1e-4, 32.0), at: start.addingTimeInterval(Double(i) * 10)) {
                flushes += 1
                r.markFlushed()
            }
        }
        #expect(flushes == 2)               // at points 5 and 10
        #expect(r.pointsSinceFlush == 2)    // 11 and 12 pending
    }

    @Test func `finish simplifies each segment at the 20 m tolerance`() {
        var r = RouteRecorder()
        // 60 fixes crawling straight north — should collapse hard.
        for i in 0..<60 {
            r.add(c(39.0 + Double(i) * 5e-6, 32.0), at: start.addingTimeInterval(Double(i) * 5))
        }
        let trace = r.finish()
        #expect(trace.segments.count == 1)
        #expect(trace.segments[0].points.count == 2)
    }

    @Test func `snapshot includes the open segment without ending recording`() {
        var r = RouteRecorder()
        r.add(c(39.0, 32.0), at: start)
        r.add(c(39.001, 32.0), at: start.addingTimeInterval(30))
        let live = r.snapshot()
        #expect(live.segments.count == 1)
        #expect(live.pointCount == 2)
        // still recording
        r.add(c(39.002, 32.0), at: start.addingTimeInterval(60))
        #expect(r.snapshot().pointCount == 3)
    }

    @Test func `An empty recorder finishes to an empty trace`() {
        var r = RouteRecorder()
        #expect(r.isEmpty)
        #expect(r.finish().isEmpty)
    }

    @Test func `Segment timestamps bracket their points`() {
        var r = RouteRecorder()
        r.add(c(39.0, 32.0), at: start)
        r.add(c(39.0, 32.001), at: start.addingTimeInterval(45))
        let seg = r.finish().segments[0]
        #expect(seg.startedAt == start)
        #expect(seg.endedAt == start.addingTimeInterval(45))
    }
}

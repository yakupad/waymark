//  DouglasPeuckerTests.swift
//  TripKitTests
//
//  Spec 12.1: Douglas-Peucker accuracy, endpoint preservation, single-point trace.

import Foundation
import Testing
import GeoData
@testable import TripKit

struct DouglasPeuckerTests {

    @Test func `Keeps a single point untouched`() {
        let p = [Coordinate(latitude: 39, longitude: 32)]
        #expect(DouglasPeucker.simplify(p, toleranceMeters: 20) == p)
    }

    @Test func `Keeps two points untouched`() {
        let p = [Coordinate(latitude: 39, longitude: 32), Coordinate(latitude: 39.1, longitude: 32.1)]
        #expect(DouglasPeucker.simplify(p, toleranceMeters: 20) == p)
    }

    @Test func `Drops near-collinear points within tolerance`() {
        // A nearly straight west→east line with a ~5 m northward blip in the middle.
        let points = [
            Coordinate(latitude: 39.00000, longitude: 32.0000),
            Coordinate(latitude: 39.00004, longitude: 32.0010),   // ~4.4 m off the line
            Coordinate(latitude: 39.00000, longitude: 32.0020),
            Coordinate(latitude: 39.00000, longitude: 32.0030),
        ]
        let simplified = DouglasPeucker.simplify(points, toleranceMeters: 20)
        #expect(simplified.count == 2)
        #expect(simplified.first == points.first)
        #expect(simplified.last == points.last)
    }

    @Test func `Keeps a point that deviates beyond tolerance`() {
        let points = [
            Coordinate(latitude: 39.0, longitude: 32.0000),
            Coordinate(latitude: 39.0010, longitude: 32.0010),   // ~110 m off the line
            Coordinate(latitude: 39.0, longitude: 32.0020),
        ]
        let simplified = DouglasPeucker.simplify(points, toleranceMeters: 20)
        #expect(simplified.count == 3)
    }

    @Test func `Always preserves the first and last point`() {
        let points = (0..<50).map { i in
            Coordinate(latitude: 39.0 + Double(i) * 1e-5, longitude: 32.0 + Double(i) * 1e-5)
        }
        let simplified = DouglasPeucker.simplify(points, toleranceMeters: 20)
        #expect(simplified.first == points.first)
        #expect(simplified.last == points.last)
        #expect(simplified.count < points.count)
    }

    @Test func `A sharp corner is retained`() {
        let points = [
            Coordinate(latitude: 39.0, longitude: 32.0),
            Coordinate(latitude: 39.0, longitude: 32.01),
            Coordinate(latitude: 39.01, longitude: 32.01),   // 90° turn
        ]
        #expect(DouglasPeucker.simplify(points, toleranceMeters: 20).count == 3)
    }

    @Test func `Every original point stays within tolerance of the simplified polyline`() {
        var points: [Coordinate] = []
        for i in 0..<200 {
            let t = Double(i)
            points.append(
                Coordinate(
                    latitude: 39.0 + sin(t / 7) * 1e-4 + t * 1e-5,
                    longitude: 32.0 + cos(t / 5) * 1e-4 + t * 2e-5
                )
            )
        }
        let tolerance = 20.0
        let simplified = DouglasPeucker.simplify(points, toleranceMeters: tolerance)

        for original in points {
            var nearestEdge = Double.infinity
            for (a, b) in zip(simplified, simplified.dropFirst()) {
                nearestEdge = min(nearestEdge, distance(from: original, toSegment: a, b))
            }
            // small slack for the equirectangular vs haversine approximation
            #expect(nearestEdge <= tolerance * 1.2)
        }
        #expect(simplified.count < points.count)
    }

    /// Metric distance from `p` to the segment `a`–`b`, via a local equirectangular projection.
    private func distance(from p: Coordinate, toSegment a: Coordinate, _ b: Coordinate) -> Double {
        let lat0 = a.latitude * .pi / 180
        let mLat = 111_132.0
        let mLon = 111_320.0 * Foundation.cos(lat0)
        let ax = 0.0, ay = 0.0
        let bx = (b.longitude - a.longitude) * mLon
        let by = (b.latitude - a.latitude) * mLat
        let px = (p.longitude - a.longitude) * mLon
        let py = (p.latitude - a.latitude) * mLat
        let dx = bx - ax, dy = by - ay
        let lenSq = dx * dx + dy * dy
        let t = lenSq == 0 ? 0 : max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / lenSq))
        let cx = ax + t * dx, cy = ay + t * dy
        return ((px - cx) * (px - cx) + (py - cy) * (py - cy)).squareRoot()
    }
}

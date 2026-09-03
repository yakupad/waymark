//  RouteBlobTests.swift
//  TripKitTests
//
//  Spec 7.7 step 4: single-blob route serialisation (spec 5.4 coordinate encoding +
//  segment boundaries). Round-trips and refuses to trap on corrupt input.

import Foundation
import Testing
import GeoData
@testable import TripKit

struct RouteBlobTests {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_123.456)

    private func trace() -> RouteTrace {
        RouteTrace(segments: [
            RouteSegment(
                points: [
                    Coordinate(latitude: 41.0082, longitude: 28.9784),
                    Coordinate(latitude: 40.7654, longitude: 29.9408),
                    Coordinate(latitude: 40.7769, longitude: 30.3948),
                ],
                startedAt: t0, endedAt: t0.addingTimeInterval(3_600)
            ),
            RouteSegment(
                points: [
                    Coordinate(latitude: 40.8533, longitude: 31.1565),
                    Coordinate(latitude: 40.9862, longitude: 37.8797),
                ],
                startedAt: t0.addingTimeInterval(7_200), endedAt: t0.addingTimeInterval(10_800)
            ),
        ])
    }

    @Test func `Round-trips coordinates, segment counts and timestamps`() throws {
        let original = trace()
        let decoded = try RouteBlob.decode(RouteBlob.encode(original))

        #expect(decoded.segments.count == 2)
        #expect(decoded.pointCount == 5)
        for (a, b) in zip(original.segments, decoded.segments) {
            #expect(abs(a.startedAt.timeIntervalSince1970 - b.startedAt.timeIntervalSince1970) < 0.001)
            #expect(abs(a.endedAt.timeIntervalSince1970 - b.endedAt.timeIntervalSince1970) < 0.001)
            for (pa, pb) in zip(a.points, b.points) {
                #expect(abs(pa.latitude - pb.latitude) < 1e-6)
                #expect(abs(pa.longitude - pb.longitude) < 1e-6)
            }
        }
    }

    @Test func `An empty trace round-trips`() throws {
        let decoded = try RouteBlob.decode(RouteBlob.encode(.empty))
        #expect(decoded.isEmpty)
    }

    @Test func `A 1500-point trace stays near the 12 KB budget (spec 7.7)`() throws {
        let points = (0..<1_500).map {
            Coordinate(latitude: 39.0 + Double($0) * 1e-4, longitude: 32.0 + Double($0) * 1e-4)
        }
        let big = RouteTrace(segments: [RouteSegment(points: points, startedAt: t0, endedAt: t0)])
        let blob = RouteBlob.encode(big)
        #expect(blob.count < 13_000)                     // 3 + 20 + 1500*8 = 12_023
        #expect(try RouteBlob.decode(blob).pointCount == 1_500)
    }

    @Test func `Empty data throws, does not trap`() {
        #expect(throws: RouteBlobError.self) { try RouteBlob.decode(Data()) }
    }

    @Test func `Unsupported version throws`() {
        #expect(throws: RouteBlobError.unsupportedVersion(9)) {
            try RouteBlob.decode(Data([9, 0, 0]))
        }
    }

    @Test func `A truncated segment header throws`() {
        // version 1, segmentCount 1, then nothing
        #expect(throws: RouteBlobError.truncatedSegmentHeader(segmentIndex: 0)) {
            try RouteBlob.decode(Data([1, 1, 0]))
        }
    }

    @Test func `A segment promising more points than present throws`() {
        var blob = Data([1, 1, 0])                       // version, segmentCount = 1
        blob.append(contentsOf: [UInt8](repeating: 0, count: 16))   // two int64 timestamps
        blob.append(contentsOf: [5, 0, 0, 0])           // pointCount = 5
        blob.append(contentsOf: [0, 0, 0, 0])           // only 4 bytes of point data
        #expect(throws: RouteBlobError.truncatedPoints(segmentIndex: 0, declared: 5)) {
            try RouteBlob.decode(blob)
        }
    }

    @Test func `Trailing bytes throw`() {
        var blob = RouteBlob.encode(.empty)
        blob.append(0x99)
        #expect(throws: RouteBlobError.trailingBytes(1)) {
            try RouteBlob.decode(blob)
        }
    }

    @Test func `Negative (western / southern) coordinates survive`() throws {
        let t = RouteTrace(segments: [
            RouteSegment(
                points: [
                    Coordinate(latitude: -33.87, longitude: -70.65),
                    Coordinate(latitude: -34.60, longitude: -58.38),
                ],
                startedAt: t0, endedAt: t0
            )
        ])
        let decoded = try RouteBlob.decode(RouteBlob.encode(t))
        #expect(abs(decoded.segments[0].points[0].latitude - (-33.87)) < 1e-6)
        #expect(abs(decoded.segments[0].points[1].longitude - (-58.38)) < 1e-6)
    }
}

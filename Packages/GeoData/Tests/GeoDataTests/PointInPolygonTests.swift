//  PointInPolygonTests.swift
//  GeoDataTests
//
//  Spec 12.1: known points, boundary points, and the enclave (inner-ring) scenario.

import Foundation
import Testing
@testable import GeoData

struct PointInPolygonTests {

    private func rings(_ blobRings: [BlobRing]) throws -> [PolygonRing] {
        try PolygonDecoder.decode(PolygonBlobBuilder.make(blobRings))
    }

    @Test func `Point inside a simple square is contained`() throws {
        let poly = try rings([PolygonBlobBuilder.square(cx: 0, cy: 0, half: 1)])
        #expect(PointInPolygon.contains(Coordinate(latitude: 0, longitude: 0), rings: poly))
        #expect(PointInPolygon.contains(Coordinate(latitude: 0.9, longitude: -0.9), rings: poly))
    }

    @Test func `Point outside a simple square is not contained`() throws {
        let poly = try rings([PolygonBlobBuilder.square(cx: 0, cy: 0, half: 1)])
        #expect(!PointInPolygon.contains(Coordinate(latitude: 5, longitude: 5), rings: poly))
        #expect(!PointInPolygon.contains(Coordinate(latitude: 0, longitude: 1.0001), rings: poly))
    }

    @Test func `Enclave: a point in the hole is not contained`() throws {
        // Outer ±1°, hole ±0.3° — mirrors the fixture's İlçe C1 enclave.
        let poly = try rings([
            PolygonBlobBuilder.square(cx: 0, cy: 0, half: 1),
            PolygonBlobBuilder.square(cx: 0, cy: 0, half: 0.3, isHole: true),
        ])
        #expect(!PointInPolygon.contains(Coordinate(latitude: 0, longitude: 0), rings: poly))
        // Between the hole edge and the outer edge -> contained.
        #expect(PointInPolygon.contains(Coordinate(latitude: 0.5, longitude: 0.5), rings: poly))
    }

    @Test func `MultiPolygon: contained if inside any outer ring`() throws {
        let poly = try rings([
            PolygonBlobBuilder.square(cx: -10, cy: 0, half: 1),
            PolygonBlobBuilder.square(cx: 10, cy: 0, half: 1),
        ])
        #expect(PointInPolygon.contains(Coordinate(latitude: 0, longitude: 10), rings: poly))
        #expect(!PointInPolygon.contains(Coordinate(latitude: 0, longitude: 0), rings: poly))
    }

    @Test func `Boundary point is classified without trapping`() throws {
        let poly = try rings([PolygonBlobBuilder.square(cx: 0, cy: 0, half: 1)])
        // On the left edge. The exact answer is not contractual (spec relies on
        // hysteresis, 7.5) — the point is only that this returns, deterministically.
        let onEdge = PointInPolygon.contains(Coordinate(latitude: 0, longitude: -1), rings: poly)
        #expect(onEdge == PointInPolygon.contains(Coordinate(latitude: 0, longitude: -1), rings: poly))
    }

    @Test func `No outer rings means nothing is contained`() throws {
        let poly = try rings([PolygonBlobBuilder.square(cx: 0, cy: 0, half: 1, isHole: true)])
        #expect(!PointInPolygon.contains(Coordinate(latitude: 0, longitude: 0), rings: poly))
    }

    @Test func `Empty ring list is not contained`() {
        #expect(!PointInPolygon.contains(Coordinate(latitude: 0, longitude: 0), rings: []))
    }
}

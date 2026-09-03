//  PolygonDecoderTests.swift
//  GeoDataTests
//
//  Spec 12.1: "Bozuk blob, sıfır ring, tek nokta ring — hepsi crash etmeden hata
//  döndürmeli." Plus a round-trip against the shared byte contract with polygon.py.

import Foundation
import Testing
@testable import GeoData

struct PolygonDecoderTests {

    @Test func `Round-trips a two-ring polygon with an enclave`() throws {
        let blob = PolygonBlobBuilder.make([
            PolygonBlobBuilder.square(cx: 31.7, cy: 39.2, half: 0.5),
            PolygonBlobBuilder.square(cx: 31.7, cy: 39.2, half: 0.12, isHole: true),
        ])

        let rings = try PolygonDecoder.decode(blob)

        #expect(rings.count == 2)
        #expect(rings[0].isHole == false)
        #expect(rings[1].isHole == true)
        #expect(rings[0].points.count == 5)
        #expect(abs(rings[0].points[0].longitude - 31.2) < 1e-6)
        #expect(abs(rings[0].points[0].latitude - 38.7) < 1e-6)
        #expect(abs(rings[1].points[2].longitude - 31.82) < 1e-6)
    }

    @Test func `Zero rings decodes to an empty polygon`() throws {
        let blob = PolygonBlobBuilder.make([])
        #expect(try PolygonDecoder.decode(blob).isEmpty)
    }

    @Test func `Empty data throws, does not trap`() {
        #expect(throws: PolygonDecodeError.self) {
            try PolygonDecoder.decode(Data())
        }
    }

    @Test func `Header-only truncation throws blobTooShort`() {
        #expect(throws: PolygonDecodeError.blobTooShort(expected: 3, got: 1)) {
            try PolygonDecoder.decode(Data([1]))
        }
    }

    @Test func `Unsupported version throws`() {
        #expect(throws: PolygonDecodeError.unsupportedVersion(2)) {
            try PolygonDecoder.decode(Data([2, 0, 0]))
        }
    }

    @Test func `Ring count larger than payload throws truncatedRingHeader`() {
        // version 1, ringCount 5, but no ring bytes follow.
        #expect(throws: PolygonDecodeError.truncatedRingHeader(ringIndex: 0)) {
            try PolygonDecoder.decode(Data([1, 5, 0]))
        }
    }

    @Test func `Single-point ring throws ringTooFewPoints`() {
        var blob = Data([1, 1, 0])          // version 1, ringCount 1
        blob.append(0)                       // isHole = 0
        blob.append(contentsOf: [1, 0, 0, 0]) // pointCount = 1 (LE)
        blob.append(contentsOf: [0, 0, 0, 0, 0, 0, 0, 0]) // one point
        #expect(throws: PolygonDecodeError.ringTooFewPoints(ringIndex: 0, count: 1)) {
            try PolygonDecoder.decode(blob)
        }
    }

    @Test func `Ring promising more points than present throws truncatedPoints`() {
        var blob = Data([1, 1, 0])
        blob.append(0)
        blob.append(contentsOf: [9, 0, 0, 0]) // pointCount = 9
        blob.append(contentsOf: [0, 0, 0, 0, 0, 0, 0, 0]) // only one point
        #expect(throws: PolygonDecodeError.truncatedPoints(ringIndex: 0, declared: 9)) {
            try PolygonDecoder.decode(blob)
        }
    }

    @Test func `Invalid hole flag throws`() {
        var blob = Data([1, 1, 0])
        blob.append(7)                       // isHole = 7 (not 0/1)
        blob.append(contentsOf: [3, 0, 0, 0])
        blob.append(contentsOf: Array(repeating: 0, count: 24))
        #expect(throws: PolygonDecodeError.invalidHoleFlag(ringIndex: 0, value: 7)) {
            try PolygonDecoder.decode(blob)
        }
    }

    @Test func `Trailing bytes after the last ring throw`() {
        var blob = PolygonBlobBuilder.make([PolygonBlobBuilder.square(cx: 0, cy: 0, half: 1)])
        blob.append(0xEE)
        #expect(throws: PolygonDecodeError.trailingBytes(1)) {
            try PolygonDecoder.decode(blob)
        }
    }

    @Test func `Negative coordinates survive the int32 round-trip`() throws {
        let blob = PolygonBlobBuilder.make([
            BlobRing(isHole: false, points: [
                (-179.999999, -85.05),
                (-170.0, -85.05),
                (-175.0, -80.0),
                (-179.999999, -85.05),
            ])
        ])
        let rings = try PolygonDecoder.decode(blob)
        #expect(abs(rings[0].points[0].longitude - (-179.999999)) < 1e-6)
        #expect(abs(rings[0].points[0].latitude - (-85.05)) < 1e-6)
    }
}

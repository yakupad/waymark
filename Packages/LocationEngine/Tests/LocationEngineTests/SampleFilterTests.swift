//  SampleFilterTests.swift
//  LocationEngineTests
//
//  Spec 7.2 / 12.1: poor accuracy, stale timestamp, impossible jump.

import Foundation
import Testing
import GeoData
@testable import LocationEngine

struct SampleFilterTests {

    private func sample(
        _ lat: Double, _ lon: Double, accuracy: Double = 10, at offset: TimeInterval = 0
    ) -> LocationSample {
        LocationSample(
            coordinate: coord(lat, lon), horizontalAccuracy: accuracy, speed: -1,
            timestamp: epoch.addingTimeInterval(offset)
        )
    }

    @Test func `Accepts a clean fix`() {
        var filter = SampleFilter()
        let result = filter.accept(sample(39, 32), now: epoch)
        #expect((try? result.get()) != nil)
    }

    @Test(arguments: [250.0, -1.0])
    func `Rejects poor horizontal accuracy`(accuracy: Double) {
        var filter = SampleFilter()
        #expect(filter.accept(sample(39, 32, accuracy: accuracy), now: epoch) == .failure(.poorAccuracy))
    }

    @Test func `Accepts accuracy exactly at the limit`() {
        var filter = SampleFilter()
        let result = filter.accept(sample(39, 32, accuracy: 200), now: epoch)
        #expect((try? result.get()) != nil)
    }

    @Test func `Rejects a stale timestamp`() {
        var filter = SampleFilter()
        // fix is 45 s older than "now"
        let result = filter.accept(sample(39, 32, at: 0), now: epoch.addingTimeInterval(45))
        #expect(result == .failure(.staleTimestamp))
    }

    @Test func `Accepts a fix 29 s old but rejects 31 s`() {
        var filter = SampleFilter()
        #expect((try? filter.accept(sample(39, 32), now: epoch.addingTimeInterval(29)).get()) != nil)
        var filter2 = SampleFilter()
        #expect(filter2.accept(sample(39, 32), now: epoch.addingTimeInterval(31)) == .failure(.staleTimestamp))
    }

    @Test func `Rejects a physically impossible jump`() {
        var filter = SampleFilter()
        _ = filter.accept(sample(39.0, 32.0, at: 0), now: epoch)
        // ~87 km east in 1 s
        let result = filter.accept(sample(39.0, 33.0, at: 1), now: epoch.addingTimeInterval(1))
        #expect(result == .failure(.impossibleJump))
    }

    @Test func `Allows a fast but plausible move`() {
        var filter = SampleFilter()
        _ = filter.accept(sample(39.0, 32.0, at: 0), now: epoch)
        // ~1.1 km in 60 s ≈ 18 m/s
        let result = filter.accept(sample(39.01, 32.0, at: 60), now: epoch.addingTimeInterval(60))
        #expect((try? result.get()) != nil)
    }

    @Test func `Rejects an out-of-order fix`() {
        var filter = SampleFilter()
        _ = filter.accept(sample(39.0, 32.0, at: 100), now: epoch.addingTimeInterval(100))
        // 10 s before the last accepted fix, but not old enough to be "stale"
        let result = filter.accept(sample(39.0, 32.001, at: 90), now: epoch.addingTimeInterval(100))
        #expect(result == .failure(.outOfOrder))
    }

    @Test func `A rejected fix does not become the speed-check baseline`() {
        var filter = SampleFilter()
        _ = filter.accept(sample(39.0, 32.0, at: 0), now: epoch)
        // impossible jump — rejected, must not update baseline
        _ = filter.accept(sample(39.0, 40.0, at: 5), now: epoch.addingTimeInterval(5))
        // a normal move from the ORIGINAL baseline should still pass
        let result = filter.accept(sample(39.001, 32.0, at: 30), now: epoch.addingTimeInterval(30))
        #expect((try? result.get()) != nil)
    }
}

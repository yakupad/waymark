//  PresenceEngineTests.swift
//  LocationEngineTests
//
//  The engine end to end against the synthetic pack: filter → resolve → parallel
//  machines. Fixture geometry: province A (id 1) contains district C1 (id 3); C1 has an
//  enclave that IS district C2 (id 4); province B (id 2) contains district D1 (id 5).

import Foundation
import Testing
import GeoData
@testable import LocationEngine

struct PresenceEngineTests {

    private func engine(_ tuning: PresenceTuning = .default) throws -> (PresenceEngine, MutableTimeSource) {
        let clock = MutableTimeSource(epoch)
        let engine = PresenceEngine(
            resolver: try fixtureResolver(), tuning: tuning, timeSource: clock
        )
        return (engine, clock)
    }

    private func feed(_ engine: PresenceEngine, _ samples: [LocationSample], _ clock: MutableTimeSource) -> [PlaceEvent] {
        var events: [PlaceEvent] = []
        for s in samples {
            clock.advance(to: s.timestamp)
            events.append(contentsOf: engine.ingest(s))
        }
        return events
    }

    @Test func `Dwelling in province A confirms tier 1 and its tier 2 child`() throws {
        let (engine, clock) = try engine()
        let events = feed(engine, dwell(at: coord(39.0, 32.0), from: epoch, count: 4), clock)
        #expect(events.ids(tier: .first) == [1])
        #expect(events.ids(tier: .second) == [3])
        // ordered tier-ascending
        #expect(events.map(\.place.tier) == [.first, .second])
    }

    @Test func `A spot inside A but outside every district confirms only tier 1`() throws {
        let (engine, clock) = try engine()
        let events = feed(engine, dwell(at: coord(39.0, 32.5), from: epoch, count: 4), clock)
        #expect(events.ids(tier: .first) == [1])
        #expect(events.ids(tier: .second) == [])
    }

    @Test func `Crossing A into B produces province events in order`() throws {
        let (engine, clock) = try engine()
        var samples = dwell(at: coord(39.0, 32.0), from: epoch, count: 3, interval: 30)
        samples += travel(from: coord(39.0, 32.0), to: coord(39.0, 34.0),
                          startingAt: epoch.addingTimeInterval(90), speed: 45)
        samples += dwell(at: coord(39.0, 34.0), from: samples.last!.timestamp.addingTimeInterval(30),
                         count: 3, interval: 30)
        let events = feed(engine, samples, clock)
        #expect(events.ids(tier: .first) == [1, 2])
    }

    @Test func `Enclave: driving from C1 through the C2 enclave switches tier 2 only`() throws {
        let (engine, clock) = try engine()
        var samples = dwell(at: coord(39.0, 31.7), from: epoch, count: 3, interval: 30)          // C1
        samples += travel(from: coord(39.0, 31.7), to: coord(39.2, 31.7),
                          startingAt: epoch.addingTimeInterval(90), speed: 25)                    // into the enclave
        samples += dwell(at: coord(39.2, 31.7), from: samples.last!.timestamp.addingTimeInterval(30),
                         count: 4, interval: 30)                                                  // C2 (in C1's hole)
        let events = feed(engine, samples, clock)
        #expect(events.ids(tier: .first) == [1])       // province never changes
        #expect(events.ids(tier: .second) == [3, 4])
    }

    @Test func `Stationary: repeated identical fixes still confirm after the dwell time`() throws {
        // Mirrors the app's heartbeat — CLLocationManager stops delivering fixes when
        // parked (distanceFilter 100 m), so the same coordinate is re-fed on a timer.
        let (engine, clock) = try engine()
        let spot = coord(39.0, 32.0)   // inside province A / district C1
        var events: [PlaceEvent] = []
        for i in 0...5 {   // 0, 15, 30, 45, 60, 75 s
            let t = epoch.addingTimeInterval(Double(i) * 15)
            clock.advance(to: t)
            events += engine.ingest(LocationSample(coordinate: spot, horizontalAccuracy: 10, speed: 0, timestamp: t))
        }
        #expect(events.ids(tier: .first) == [1])
        #expect(events.ids(tier: .second) == [3])
    }

    @Test func `A poor-accuracy fix is dropped and changes nothing`() throws {
        let (engine, clock) = try engine()
        _ = feed(engine, dwell(at: coord(39.0, 32.0), from: epoch, count: 4), clock)
        let before = engine.states

        let bad = LocationSample(
            coordinate: coord(41.0, 29.0), horizontalAccuracy: 500, speed: -1,
            timestamp: epoch.addingTimeInterval(1_000)
        )
        clock.advance(to: bad.timestamp)
        let events = engine.ingest(bad)

        #expect(events.isEmpty)
        #expect(engine.lastRejection == .poorAccuracy)
        #expect(engine.states == before)
    }

    @Test func `Settlement machine confirms within settlementRadius`() throws {
        // "Köy Bir" (id 1) sits at (39.05, 31.55).
        let (engine, clock) = try engine()
        let events = feed(engine, dwell(at: coord(39.052, 31.551), from: epoch, count: 4), clock)
        #expect(events.settlementIDs == [1])
    }

    @Test func `reset clears every machine`() throws {
        let (engine, clock) = try engine()
        _ = feed(engine, dwell(at: coord(39.0, 32.0), from: epoch, count: 4), clock)
        engine.reset()
        #expect(engine.states.values.allSatisfy { $0 == .unknown })
        #expect(engine.lastRejection == nil)
    }

    @Test func `The engine is safe to hammer from many tasks`() async throws {
        let (engine, clock) = try engine()
        clock.advance(to: epoch.addingTimeInterval(10_000))
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<32 {
                group.addTask {
                    _ = engine.ingest(
                        LocationSample(
                            coordinate: coord(39.0, 32.0), horizontalAccuracy: 10, speed: -1,
                            timestamp: epoch.addingTimeInterval(10_000 + Double(i))
                        )
                    )
                }
            }
        }
        // no crash / data race; some machine reached a non-unknown state
        #expect(engine.states[.tier(.first)] != nil)
    }
}

//  PresenceMachineTests.swift
//  LocationEngineTests
//
//  The transition table (spec 7.4) in isolation — no resolver, no pack. The machine is
//  fed the matched ref directly.

import Foundation
import Testing
import GeoData
@testable import LocationEngine

struct PresenceMachineTests {

    private let placeA = PlaceRef(kind: .administrative, tier: .first, id: 1)
    private let placeB = PlaceRef(kind: .administrative, tier: .first, id: 2)
    private let here = Coordinate(latitude: 39, longitude: 32)

    private func machine(_ tuning: PresenceTuning = .default) -> PresenceMachine {
        PresenceMachine(key: .tier(.first), tuning: tuning)
    }

    @Test func `unknown to candidate on first match`() {
        var m = machine()
        let event = m.step(matchedRef: placeA, coordinate: here, timestamp: epoch)
        #expect(event == nil)
        #expect(m.state.place == placeA)
        #expect(!m.state.isConfirmed)
    }

    @Test func `candidate to confirmed after the dwell time, emitting one event`() {
        var m = machine()
        _ = m.step(matchedRef: placeA, coordinate: here, timestamp: epoch)
        let event = m.step(matchedRef: placeA, coordinate: here, timestamp: epoch.addingTimeInterval(60))
        let confirmed = try! #require(event)
        #expect(confirmed.place == placeA)
        #expect(confirmed.enteredAt == epoch)      // entry time, not confirmation time
        #expect(m.state.isConfirmed)
    }

    @Test func `candidate to confirmed by distance before the dwell time`() {
        var m = machine()
        _ = m.step(matchedRef: placeA, coordinate: coord(39, 32), timestamp: epoch)
        // ~2.2 km north in 10 s — past confirmDwellDistance, well under confirmDwellTime
        let event = m.step(
            matchedRef: placeA, coordinate: coord(39.02, 32), timestamp: epoch.addingTimeInterval(10)
        )
        #expect(event?.place == placeA)
    }

    @Test func `candidate does not confirm early`() {
        var m = machine()
        _ = m.step(matchedRef: placeA, coordinate: here, timestamp: epoch)
        let event = m.step(matchedRef: placeA, coordinate: here, timestamp: epoch.addingTimeInterval(59))
        #expect(event == nil)
    }

    @Test func `candidate switches to a different place without an event`() {
        var m = machine()
        _ = m.step(matchedRef: placeA, coordinate: here, timestamp: epoch)
        let event = m.step(matchedRef: placeB, coordinate: here, timestamp: epoch.addingTimeInterval(20))
        #expect(event == nil)
        #expect(m.state.place == placeB)
    }

    @Test func `candidate falls back to unknown when it matches nothing`() {
        var m = machine()
        _ = m.step(matchedRef: placeA, coordinate: here, timestamp: epoch)
        _ = m.step(matchedRef: nil, coordinate: here, timestamp: epoch.addingTimeInterval(20))
        #expect(m.state == .unknown)
    }

    @Test func `confirmed to exiting when the match is lost`() {
        var m = confirmedMachine()
        _ = m.step(matchedRef: nil, coordinate: coord(39, 33), timestamp: epoch.addingTimeInterval(120))
        if case .exiting(let place, _, _, _) = m.state {
            #expect(place == placeA)
        } else {
            Issue.record("expected .exiting, got \(m.state)")
        }
    }

    @Test func `exiting back to confirmed on re-entry, no event, original entry time kept`() {
        var m = confirmedMachine()               // confirmed placeA since `epoch`
        _ = m.step(matchedRef: nil, coordinate: coord(39, 33), timestamp: epoch.addingTimeInterval(120))
        let event = m.step(
            matchedRef: placeA, coordinate: coord(39, 32), timestamp: epoch.addingTimeInterval(150)
        )
        #expect(event == nil)
        #expect(m.state == .confirmed(place: placeA, since: epoch))
    }

    @Test func `brief jitter across the border does not complete an exit (hysteresis)`() {
        var m = confirmedMachine()
        // step out ~200 m, stay 5 min — under exitBufferDistance (750 m)
        for i in 1...10 {
            let t = epoch.addingTimeInterval(120 + Double(i) * 30)
            _ = m.step(matchedRef: nil, coordinate: coord(39.0018, 32), timestamp: t)
        }
        // never dropped to unknown
        #expect(m.state.place == placeA)
        #expect(!m.state.isConfirmed)  // it's in .exiting, holding
    }

    @Test func `exiting completes only when far enough AND long enough, then re-arms`() {
        var m = confirmedMachine()
        _ = m.step(matchedRef: nil, coordinate: coord(39, 32.01), timestamp: epoch.addingTimeInterval(120))
        // 3 km away and 100 s later -> exit completes; already inside placeB -> new candidate
        let event = m.step(
            matchedRef: placeB, coordinate: coord(39, 32.05), timestamp: epoch.addingTimeInterval(220)
        )
        #expect(event == nil)                       // candidate, not yet confirmed
        #expect(m.state.place == placeB)
        #expect(!m.state.isConfirmed)
    }

    @Test func `a full pass produces exactly one event per place`() {
        var m = machine()
        var events: [PlaceEvent] = []
        // 5 min parked in A, then drive east through B, fixes every 30 s
        for i in 0..<10 {
            if let e = m.step(matchedRef: placeA, coordinate: here, timestamp: epoch.addingTimeInterval(Double(i) * 30)) {
                events.append(e)
            }
        }
        for i in 10..<20 {
            let lon = 34.0 + Double(i - 10) * 0.002   // ~170 m per step
            if let e = m.step(matchedRef: placeB, coordinate: coord(39, lon), timestamp: epoch.addingTimeInterval(Double(i) * 30)) {
                events.append(e)
            }
        }
        #expect(events.map(\.place) == [placeA, placeB])
    }

    // MARK: -

    private func confirmedMachine() -> PresenceMachine {
        var m = machine()
        _ = m.step(matchedRef: placeA, coordinate: coord(39, 32), timestamp: epoch)
        _ = m.step(matchedRef: placeA, coordinate: coord(39, 32), timestamp: epoch.addingTimeInterval(60))
        precondition(m.state.isConfirmed)
        return m
    }
}

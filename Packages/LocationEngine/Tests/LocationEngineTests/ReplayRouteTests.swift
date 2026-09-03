//  ReplayRouteTests.swift
//  LocationEngineTests
//
//  Spec 12.3: the five recorded routes. The real traces and the real `tr.pack` do not
//  exist yet (same state as F1/F2 — see Fixtures/gpx/README.md), so these are disabled
//  skeletons carrying the exact expected sequences from spec 12.2. When the data lands,
//  drop a `<name>.gpx` next to the synthetic ones, swap in the real pack, and remove
//  `.disabled`.

import Foundation
import Testing
import GeoData
@testable import LocationEngine

@Suite(.disabled("needs the real tr.pack + recorded GPX traces — see Fixtures/gpx/README.md"))
struct ReplayRouteTests {

    private func replay(_ route: String, tuning: PresenceTuning = .default) throws -> ([PlaceEvent], SQLiteGeoResolver) {
        let track = try GPXTrack.parse(contentsOf: try gpxURL(route))
        let clock = MutableTimeSource(Date(timeIntervalSince1970: 0))
        let resolver = try fixtureResolver()   // -> real tr.pack once available
        let engine = PresenceEngine(resolver: resolver, tuning: tuning, timeSource: clock)
        return (GPXReplayer().replay(track, into: engine, advancing: clock), resolver)
    }

    /// Spec 12.2 — the primary scenario.
    @Test func `istanbul-ordu produces the expected province sequence`() throws {
        let (events, resolver) = try replay("istanbul-ordu")
        let provinces = events
            .filter { $0.place.tier == .first }
            .compactMap { try? resolver.place(for: $0.place, language: "tr")?.nameLocal }
        #expect(provinces == [
            "İstanbul", "Kocaeli", "Sakarya", "Düzce", "Bolu",
            "Çankırı", "Çorum", "Amasya", "Tokat", "Ordu",
        ])
    }

    @Test func `boundary-oscillation fires each province once despite the wobble`() throws {
        let (events, _) = try replay("boundary-oscillation")
        let provinceIDs = events.filter { $0.place.tier == .first }.map(\.place.id)
        #expect(provinceIDs.count == Set(provinceIDs).count)   // no repeats
    }

    @Test func `village-cluster respects the per-hour notification ceiling upstream`() throws {
        // The engine emits every confirmed settlement; the cap is Presence's job (F6).
        let (events, _) = try replay("village-cluster")
        #expect(events.contains { $0.place.kind == .settlement })
    }

    @Test func `urban-slow does not confirm places while crawling through a city`() throws {
        let (events, _) = try replay("urban-slow", tuning: .default)
        #expect(events.filter { $0.place.tier == .second }.isEmpty)
    }

    @Test func `poor-signal survives long gaps without spurious events`() throws {
        let (events, resolver) = try replay("poor-signal")
        let provinces = events
            .filter { $0.place.tier == .first }
            .compactMap { try? resolver.place(for: $0.place, language: "tr")?.nameLocal }
        #expect(provinces == provinces.reduced())   // no adjacent duplicates
    }
}

private extension Array where Element == String {
    /// Collapse adjacent duplicates.
    func reduced() -> [String] {
        reduce(into: []) { if $0.last != $1 { $0.append($1) } }
    }
}

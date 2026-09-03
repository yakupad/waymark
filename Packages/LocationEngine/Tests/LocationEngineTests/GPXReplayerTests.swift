//  GPXReplayerTests.swift
//  LocationEngineTests
//
//  Spec 12.2: the replay harness — parse a GPX trace, feed it to the engine, check the
//  event sequence.

import Foundation
import Testing
import GeoData
@testable import LocationEngine

struct GPXReplayerTests {

    private let sampleGPX = """
    <?xml version="1.0" encoding="UTF-8"?>
    <gpx version="1.1" creator="test">
      <trk><trkseg>
        <trkpt lat="39.0" lon="32.0"><time>2026-01-01T08:00:00Z</time></trkpt>
        <trkpt lat="39.1" lon="32.2"><time>2026-01-01T08:10:00Z</time></trkpt>
        <trkpt lat="39.2" lon="32.4"></trkpt>
      </trkseg></trk>
    </gpx>
    """

    @Test func `Parses track points, coordinates and timestamps`() throws {
        let track = try GPXTrack.parse(Data(sampleGPX.utf8))
        #expect(track.points.count == 3)
        #expect(track.points[0].coordinate == Coordinate(latitude: 39.0, longitude: 32.0))
        #expect(track.points[1].time == ISO8601DateFormatter().date(from: "2026-01-01T08:10:00Z"))
        #expect(track.points[2].time == nil)   // missing <time>
    }

    @Test func `Malformed XML throws, does not trap`() {
        #expect(throws: (any Error).self) {
            try GPXTrack.parse(Data("<gpx><trk>".utf8))
        }
    }

    @Test func `samples(from:) places a timeless point after the previous one`() throws {
        let track = try GPXTrack.parse(Data(sampleGPX.utf8))
        var replayer = GPXReplayer()
        replayer.syntheticInterval = 5
        let samples = replayer.samples(from: track)
        #expect(samples.count == 3)
        #expect(samples[2].timestamp == samples[1].timestamp.addingTimeInterval(5))
    }

    @Test func `Replay advances the injected clock so historical fixes are not stale`() throws {
        let track = try GPXTrack.parse(contentsOf: try gpxURL("synthetic-cross-provinces"))
        let clock = MutableTimeSource(Date(timeIntervalSince1970: 0))
        let engine = PresenceEngine(resolver: try fixtureResolver(), timeSource: clock)

        let events = GPXReplayer().replay(track, into: engine, advancing: clock)

        // If the clock had not advanced, every fix would be decades stale and dropped.
        #expect(!events.isEmpty)
        #expect(engine.lastRejection != .staleTimestamp)
    }

    @Test func `Cross-provinces trace yields the expected province and district events`() throws {
        let track = try GPXTrack.parse(contentsOf: try gpxURL("synthetic-cross-provinces"))
        let clock = MutableTimeSource(Date(timeIntervalSince1970: 0))
        let resolver = try fixtureResolver()
        let engine = PresenceEngine(resolver: resolver, timeSource: clock)

        let events = GPXReplayer().replay(track, into: engine, advancing: clock)

        #expect(events.ids(tier: .first) == [1, 2])
        #expect(events.ids(tier: .second) == [3, 5])

        // The spec 12.2 shape: events -> place names.
        let provinceNames = events
            .filter { $0.place.tier == .first }
            .map { try? resolver.place(for: $0.place, language: "tr")?.nameLocal }
        #expect(provinceNames == ["Test İli A", "Test İli B"])
    }

    @Test func `Riding the border does not spam province events (hysteresis)`() throws {
        let track = try GPXTrack.parse(contentsOf: try gpxURL("synthetic-boundary-oscillation"))
        let clock = MutableTimeSource(Date(timeIntervalSince1970: 0))
        let engine = PresenceEngine(resolver: try fixtureResolver(), timeSource: clock)

        let events = GPXReplayer().replay(track, into: engine, advancing: clock)

        #expect(events.ids(tier: .first) == [1])   // confirmed A once, never flips to B
        #expect(events.ids(tier: .second) == [])
    }
}

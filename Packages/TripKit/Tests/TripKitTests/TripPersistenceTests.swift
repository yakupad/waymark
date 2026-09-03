//  TripPersistenceTests.swift
//  TripKitTests
//
//  Spec §9 / P8: SwiftData round-trip, single-blob route storage, R4 recovery,
//  delete + delete-route.

import Foundation
import SwiftData
import Testing
import GeoData
import LocationEngine
@testable import TripKit

@MainActor
struct TripPersistenceTests {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func event(_ tier: Int?, _ id: Int, at offset: TimeInterval) -> PlaceEvent {
        PlaceEvent(
            place: PlaceRef(
                kind: tier == nil ? .settlement : .administrative,
                tier: tier.map(Tier.init(rawValue:)), id: id
            ),
            enteredAt: t0.addingTimeInterval(offset),
            coordinate: Coordinate(latitude: 39, longitude: 32)
        )
    }

    private func route() -> RouteTrace {
        RouteTrace(segments: [
            RouteSegment(
                points: [
                    Coordinate(latitude: 41.0, longitude: 29.0),
                    Coordinate(latitude: 40.8, longitude: 31.0),
                ],
                startedAt: t0, endedAt: t0.addingTimeInterval(3_600)
            )
        ])
    }

    @Test func `Start, checkpoint, finish, reload`() throws {
        let store = try TripStore(inMemory: true)

        let record = try store.startTrip(at: t0, recordsRoute: true)
        #expect(!record.isFinished)

        let events = [event(1, 34, at: 0), event(2, 340, at: 600)]
        try store.checkpoint(record, events: events, route: route(), distanceMeters: 12_345)
        try store.finishTrip(
            record, at: t0.addingTimeInterval(7_200), events: events,
            route: route(), distanceMeters: 54_321, title: "İstanbul → Ordu"
        )

        let reloaded = try #require(try store.trip(id: record.id))
        #expect(reloaded.isFinished)
        #expect(reloaded.title == "İstanbul → Ordu")
        #expect(reloaded.distanceMeters == 54_321)
        #expect(reloaded.events.count == 2)
        #expect(reloaded.route?.segments.count == 1)
    }

    @Test func `The route is one Data blob, not per-point objects`() throws {
        let store = try TripStore(inMemory: true)
        let record = try store.startTrip(at: t0, recordsRoute: true)
        try store.finishTrip(
            record, at: t0.addingTimeInterval(60), events: [], route: route(),
            distanceMeters: 0, title: nil
        )
        // one attribute holds the whole polyline
        #expect(record.routeData != nil)
        let decoded = try RouteBlob.decode(try #require(record.routeData))
        #expect(decoded.pointCount == 2)
    }

    @Test func `Route recording off means no route is stored even if one is passed`() throws {
        let store = try TripStore(inMemory: true)
        let record = try store.startTrip(at: t0, recordsRoute: false)
        try store.checkpoint(record, events: [], route: route(), distanceMeters: 0)
        try store.finishTrip(record, at: t0, events: [], route: route(), distanceMeters: 0, title: nil)
        #expect(record.routeData == nil)
    }

    @Test func `Unfinished trip is recoverable after a simulated relaunch`() throws {
        let container = try inMemoryContainer()
        do {
            let store = TripStore(container: container)
            let record = try store.startTrip(at: t0, recordsRoute: true)
            try store.checkpoint(record, events: [event(1, 34, at: 0)], route: route(), distanceMeters: 900)
            // no finishTrip — the app was killed
        }
        // "relaunch": a fresh store over the same container
        let store2 = TripStore(container: container)
        let recovered = try #require(try store2.unfinishedTrip())
        #expect(!recovered.isFinished)
        #expect(recovered.events.count == 1)
        #expect(recovered.distanceMeters == 900)
    }

    @Test func `A finished trip is not offered for recovery`() throws {
        let store = try TripStore(inMemory: true)
        let record = try store.startTrip(at: t0, recordsRoute: true)
        try store.finishTrip(record, at: t0.addingTimeInterval(60), events: [], route: nil, distanceMeters: 0, title: nil)
        #expect(try store.unfinishedTrip() == nil)
    }

    @Test func `deleteRoute keeps the trip and its events`() throws {
        let store = try TripStore(inMemory: true)
        let record = try store.startTrip(at: t0, recordsRoute: true)
        try store.finishTrip(
            record, at: t0.addingTimeInterval(60), events: [event(1, 34, at: 0)],
            route: route(), distanceMeters: 100, title: "X"
        )
        try store.deleteRoute(from: record)
        let reloaded = try #require(try store.trip(id: record.id))
        #expect(reloaded.route == nil)
        #expect(reloaded.events.count == 1)
        #expect(reloaded.title == "X")
    }

    @Test func `delete and deleteAll`() throws {
        let store = try TripStore(inMemory: true)
        let a = try store.startTrip(at: t0, recordsRoute: true)
        _ = try store.startTrip(at: t0.addingTimeInterval(100), recordsRoute: true)
        #expect(try store.allTrips().count == 2)

        try store.delete(a)
        #expect(try store.allTrips().count == 1)

        try store.deleteAll()
        #expect(try store.allTrips().isEmpty)
    }

    @Test func `allTrips is newest first`() throws {
        let store = try TripStore(inMemory: true)
        _ = try store.startTrip(at: t0, recordsRoute: true)
        _ = try store.startTrip(at: t0.addingTimeInterval(1_000), recordsRoute: true)
        let trips = try store.allTrips()
        #expect(trips.first!.startedAt > trips.last!.startedAt)
    }

    // MARK: -

    private func inMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: TripRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}

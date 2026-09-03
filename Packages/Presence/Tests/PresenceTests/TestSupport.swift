//  TestSupport.swift
//  PresenceTests

import Foundation
import Testing
import GeoData
import LocationEngine
import TripKit
@testable import Presence

let t0 = Date(timeIntervalSince1970: 1_700_000_000)

func adminRef(_ tier: Int, _ id: Int) -> PlaceRef {
    PlaceRef(kind: .administrative, tier: Tier(rawValue: tier), id: id)
}

func settlementRef(_ id: Int) -> PlaceRef {
    PlaceRef(kind: .settlement, tier: nil, id: id)
}

func event(_ ref: PlaceRef, at offset: TimeInterval = 0) -> PlaceEvent {
    PlaceEvent(
        place: ref, enteredAt: t0.addingTimeInterval(offset),
        coordinate: Coordinate(latitude: 39, longitude: 32)
    )
}

func makePlace(
    _ ref: PlaceRef, name: String, parent: String? = nil, population: Int? = nil
) -> Place {
    Place(
        ref: ref, nameLocal: name, nameLocalized: nil, tierLabel: "",
        parentName: parent, population: population, populationYear: nil,
        areaKm2: nil, elevationMeters: nil, article: nil,
        centroid: Coordinate(latitude: 39, longitude: 32)
    )
}

final class FakePlaceRepository: PlaceRepository, @unchecked Sendable {
    var places: [Int: Place] = [:]

    func add(_ place: Place) { places[place.ref.id] = place }
    func tierLabels() throws -> [TierLabel] { [] }
    func place(for ref: PlaceRef, language: String) throws -> Place? { places[ref.id] }
}

actor RecordingActivitySurface: ActivitySurface {
    private(set) var started: [(state: LiveActivityState, thread: String)] = []
    private(set) var updates: [LiveActivityState] = []
    private(set) var ended: [LiveActivityState] = []

    func start(_ state: LiveActivityState, thread: String) async {
        started.append((state, thread))
    }
    func update(_ state: LiveActivityState) async { updates.append(state) }
    func end(_ state: LiveActivityState) async { ended.append(state) }
}

actor RecordingNotificationSurface: NotificationSurface {
    private(set) var posted: [PlaceNotification] = []
    private(set) var authRequests = 0

    func requestAuthorization() async -> Bool { authRequests += 1; return true }
    func post(_ notification: PlaceNotification) async { posted.append(notification) }
}

func makeCoordinator(
    repo: FakePlaceRepository,
    activity: RecordingActivitySurface,
    notifications: RecordingNotificationSurface,
    sensitivity: NotificationSensitivity = .tier1,
    gate: NotificationGate = NotificationGate(),
    clock: MutableTimeSource,
    language: String = "tr"
) -> PresenceCoordinator {
    PresenceCoordinator(
        activity: activity,
        notifications: notifications,
        places: repo,
        policy: PresencePolicy(sensitivity: sensitivity),
        gate: gate,
        coalescer: UpdateCoalescer(interval: 60),
        timeSource: clock,
        language: language
    )
}

func makeTrip() -> Trip {
    Trip(id: UUID(), startedAt: t0)
}

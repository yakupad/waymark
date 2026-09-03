//  LiveTripController.swift
//  waymark
//
//  Owns an in-progress trip: wires the location provider → `PresenceEngine` (detection)
//  and → `RouteRecorder` (trace), routes confirmed events to `PresenceCoordinator`
//  (Live Activity + push), and checkpoints to `TripStore` on every route flush (R4).
//
//  `@Observable` so the active-trip screen renders live.

import Foundation
import SwiftUI
import GeoData
import LocationEngine
import TripKit
import Presence

@MainActor
@Observable
final class LiveTripController {

    struct PassedPlace: Identifiable, Equatable {
        let id: UUID
        let ref: PlaceRef
        let name: String
        let tierLabel: String
        let parentName: String?
        let population: Int?
        let enteredAt: Date
    }

    private(set) var isRunning = false
    /// The last *confirmed* place (spec 7.4). Drives the notification / Live Activity.
    private(set) var headline: String?
    private(set) var hierarchy: String?
    /// Where the latest fix resolves right now — shown (dimmed) before a place is
    /// confirmed, so the screen isn't stuck on "Locating…" for the first minute.
    private(set) var pendingPlace: String?
    private(set) var fixCount = 0
    private(set) var passedPlaces: [PassedPlace] = []
    private(set) var route: RouteTrace = .empty
    private(set) var distanceMeters: Double = 0
    private(set) var startedAt: Date?
    /// The most recent coordinate — the active-trip map centres on it.
    private(set) var currentCoordinate: Coordinate?

    private let env: AppEnvironment
    private let permissions: PermissionsModel
    private var engine: PresenceEngine?
    private var recorder = RouteRecorder()
    private var record: TripRecord?
    private var events: [PlaceEvent] = []
    private var lastFix: Coordinate?
    /// Fires while stationary so the dwell timer (spec 7.4 "süre ≥ 60s") still advances
    /// even when `CLLocationManager` stops delivering fixes (distanceFilter = 100 m).
    private var heartbeat: Timer?
    /// First / last accepted fix time — the trip's real span (with the simulator these
    /// are simulated seconds, so wall-clock start/end would read as "0 min").
    private var firstFixAt: Date?
    private var lastFixAt: Date?

    init(env: AppEnvironment, permissions: PermissionsModel) {
        self.env = env
        self.permissions = permissions
    }

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }
        let timeSource: any TimeSource = (env.locationProvider as? SimulatedLocationProvider)?.clock ?? SystemTimeSource()
        engine = PresenceEngine(resolver: env.resolver, tuning: env.settings.tuning, timeSource: timeSource)
        recorder = RouteRecorder()
        events = []
        passedPlaces = []
        route = .empty
        distanceMeters = 0
        lastFix = nil
        currentCoordinate = nil
        firstFixAt = nil
        lastFixAt = nil
        fixCount = 0
        headline = nil
        hierarchy = nil
        pendingPlace = nil

        let now = Date()
        startedAt = now
        record = try? env.tripStore.startTrip(at: now, recordsRoute: env.settings.recordRouteTrace)
        isRunning = true

        env.locationProvider.delegate = self
        permissions.onTripStarted()
        env.locationProvider.startTracking(configuration: TrackingConfiguration())

        heartbeat = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }

        Task { await env.presence.startActivity(for: currentTrip()) }
    }

    /// Re-run detection at `now` with the last coordinate, so dwell/exit timers advance
    /// while the traveller is stopped (a red light, a rest stop, a slow GPS). Also flushes
    /// any Live Activity update held by the 60 s coalescer (spec 8.2) — nothing else
    /// drives that flush.
    private func tick() {
        guard isRunning else { return }
        if let engine, let lastFix {
            let events = engine.ingest(LocationSample(
                coordinate: lastFix, horizontalAccuracy: 10, speed: 0, timestamp: Date()
            ))
            for event in events {
                self.events.append(event)
                appendPassed(event)
                Task { await env.presence.update(with: event) }
            }
        }
        Task { await env.presence.flushPendingActivityUpdate() }
    }

    /// Ends the trip, persists it, and returns the summary for the summary screen.
    @discardableResult
    func stop() -> TripSummary {
        guard isRunning else { return TripSummary() }
        isRunning = false
        permissions.onTripEnded()
        heartbeat?.invalidate()
        heartbeat = nil
        env.locationProvider.stopTracking()
        env.locationProvider.delegate = nil

        let finalRoute = recorder.finish()
        route = finalRoute
        let title = Trip.autoTitle(from: events) { [env] ref in
            try? env.resolver.place(for: ref, language: env.language)?.nameLocal
        }
        let endedAt = lastFixAt ?? Date()
        if let record {
            try? env.tripStore.finishTrip(
                record, at: endedAt, events: events, route: finalRoute,
                distanceMeters: distanceMeters, title: title, startedAt: firstFixAt
            )
        }

        let summary = TripSummary.make(from: currentTrip(route: finalRoute, title: title)) { [env] ref in
            try? env.resolver.place(for: ref, language: env.language)
        }
        Task { await env.presence.endActivity(summary: summary) }
        return summary
    }

    var finishedTripID: UUID? { record?.id }

    // MARK: -

    private func currentTrip(route: RouteTrace? = nil, title: String? = nil) -> Trip {
        Trip(
            id: record?.id ?? UUID(),
            startedAt: firstFixAt ?? startedAt ?? Date(),
            endedAt: lastFixAt,
            events: events,
            distanceMeters: distanceMeters,
            title: title,
            route: route
        )
    }

    private func ingest(_ sample: LocationSample) {
        guard let engine else { return }

        if firstFixAt == nil { firstFixAt = sample.timestamp }
        lastFixAt = sample.timestamp
        fixCount += 1
        currentCoordinate = sample.coordinate

        // Live "where am I" readout, independent of the confirm/dwell state machine.
        if let resolution = try? env.resolver.resolve(coordinate: sample.coordinate) {
            let deepest = resolution.administrative
                .sorted { $0.key > $1.key }
                .first?.value
            pendingPlace = (deepest ?? resolution.settlement)
                .flatMap { try? env.resolver.place(for: $0, language: env.language)?.nameLocal }
        }

        if let last = lastFix {
            distanceMeters += Haversine.distance(last, sample.coordinate)
        }
        lastFix = sample.coordinate

        let flushDue = recorder.add(sample.coordinate, at: sample.timestamp)
        route = recorder.snapshot()

        let newEvents = engine.ingest(sample)
        for event in newEvents {
            events.append(event)
            appendPassed(event)
            Task { await env.presence.update(with: event) }
        }

        if flushDue || !newEvents.isEmpty, let record {
            recorder.markFlushed()
            try? env.tripStore.checkpoint(
                record, events: events, route: recorder.snapshot(), distanceMeters: distanceMeters
            )
        }
    }

    private func appendPassed(_ event: PlaceEvent) {
        // A quick exit-and-return across a boundary re-confirms the same place; don't
        // add a duplicate row (the notification cooldown already suppresses the re-alert).
        if passedPlaces.first?.ref == event.place { return }
        guard let place = try? env.resolver.place(for: event.place, language: env.language) else { return }
        let passed = PassedPlace(
            id: event.id, ref: event.place, name: place.nameLocal,
            tierLabel: place.tierLabel, parentName: place.parentName,
            population: place.population, enteredAt: event.enteredAt
        )
        passedPlaces.insert(passed, at: 0)   // reverse chronological (spec §10)
        headline = place.nameLocal
        hierarchy = [place.nameLocal, place.parentName].compactMap { $0 }.joined(separator: ", ")
    }
}

extension LiveTripController: LocationProvidingDelegate {
    func locationProvider(_ provider: any LocationProviding, didUpdate sample: LocationSample) {
        ingest(sample)
    }
}

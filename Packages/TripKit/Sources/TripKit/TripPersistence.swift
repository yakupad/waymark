//  TripPersistence.swift
//  TripKit
//
//  SwiftData persistence for trips (spec §9, prompt P8). The route trace is stored as a
//  single `Data` blob (spec 7.7) — never one model object per point. Events are stored
//  as a JSON blob for the same reason: a trip has tens of events, not thousands, but a
//  blob keeps the schema flat and the store fast.

import Foundation
import SwiftData
import GeoData
import LocationEngine

/// JSON codec for a trip's event list. Lenient on read so a schema tweak never loses a
/// whole trip.
enum TripEventsCodec {
    static func encode(_ events: [PlaceEvent]) -> Data {
        (try? JSONEncoder().encode(events)) ?? Data()
    }

    static func decode(_ data: Data) -> [PlaceEvent] {
        (try? JSONDecoder().decode([PlaceEvent].self, from: data)) ?? []
    }
}

@Model
public final class TripRecord {
    @Attribute(.unique) public var id: UUID
    public var startedAt: Date
    public var endedAt: Date?
    public var distanceMeters: Double
    public var title: String?
    /// JSON `[PlaceEvent]`.
    public var eventsData: Data
    /// `RouteBlob` bytes. `nil` when route recording is off or the user deleted the route.
    public var routeData: Data?
    /// Whether this trip is recording a route trace (spec 7.7 user switch).
    public var recordsRoute: Bool

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date? = nil,
        distanceMeters: Double = 0,
        title: String? = nil,
        events: [PlaceEvent] = [],
        route: RouteTrace? = nil,
        recordsRoute: Bool = true
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.distanceMeters = distanceMeters
        self.title = title
        self.eventsData = TripEventsCodec.encode(events)
        self.routeData = route.map(RouteBlob.encode)
        self.recordsRoute = recordsRoute
    }

    public var isFinished: Bool { endedAt != nil }

    public var events: [PlaceEvent] {
        TripEventsCodec.decode(eventsData)
    }

    public var route: RouteTrace? {
        guard let routeData else { return nil }
        return try? RouteBlob.decode(routeData)
    }

    /// A plain `Trip` snapshot (spec §9) for the domain layer.
    public func asTrip() -> Trip {
        Trip(
            id: id, startedAt: startedAt, endedAt: endedAt, events: events,
            distanceMeters: distanceMeters, title: title, route: route
        )
    }
}

@MainActor
public final class TripStore {

    private let container: ModelContainer

    private var context: ModelContext { container.mainContext }

    public init(container: ModelContainer) {
        self.container = container
    }

    public convenience init(inMemory: Bool = false) throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        self.init(container: try ModelContainer(for: TripRecord.self, configurations: configuration))
    }

    // MARK: - Lifecycle

    public func startTrip(at date: Date, recordsRoute: Bool) throws -> TripRecord {
        let record = TripRecord(startedAt: date, recordsRoute: recordsRoute)
        context.insert(record)
        try context.save()
        return record
    }

    /// Persist the in-progress state (spec 7.7 step 2 / R4): call this on every route
    /// buffer flush so a background kill loses at most the last ~200 points.
    public func checkpoint(
        _ record: TripRecord, events: [PlaceEvent], route: RouteTrace?, distanceMeters: Double
    ) throws {
        record.eventsData = TripEventsCodec.encode(events)
        record.distanceMeters = distanceMeters
        if record.recordsRoute {
            record.routeData = route.map(RouteBlob.encode)
        }
        try context.save()
    }

    public func finishTrip(
        _ record: TripRecord, at date: Date, events: [PlaceEvent],
        route: RouteTrace?, distanceMeters: Double, title: String?, startedAt: Date? = nil
    ) throws {
        if let startedAt { record.startedAt = startedAt }
        record.endedAt = date
        record.eventsData = TripEventsCodec.encode(events)
        record.distanceMeters = distanceMeters
        record.title = title
        record.routeData = record.recordsRoute ? route.map(RouteBlob.encode) : nil
        try context.save()
    }

    // MARK: - R4 recovery

    /// The most recent trip that never got an `endedAt` — a candidate to resume or
    /// finalise after a background termination (spec R4).
    public func unfinishedTrip() throws -> TripRecord? {
        var descriptor = FetchDescriptor<TripRecord>(
            predicate: #Predicate { $0.endedAt == nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    // MARK: - Queries

    public func allTrips() throws -> [TripRecord] {
        try context.fetch(
            FetchDescriptor<TripRecord>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        )
    }

    public func trip(id: UUID) throws -> TripRecord? {
        var descriptor = FetchDescriptor<TripRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    // MARK: - Mutations

    public func delete(_ record: TripRecord) throws {
        context.delete(record)
        try context.save()
    }

    /// Remove only the route trace, keeping the trip and its events (spec 7.7:
    /// "Rotayı sil").
    public func deleteRoute(from record: TripRecord) throws {
        record.routeData = nil
        try context.save()
    }

    public func deleteAll() throws {
        try context.delete(model: TripRecord.self)
        try context.save()
    }
}

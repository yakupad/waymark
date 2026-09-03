//  Trip.swift
//  TripKit
//
//  The trip value model (spec §9). F6 wraps SwiftData persistence around this; the
//  struct itself stays plain so `Presence` and tests can use it without a store.

import Foundation
import GeoData
import LocationEngine

public struct Trip: Identifiable, Sendable, Equatable {
    public let id: UUID
    public var startedAt: Date
    public var endedAt: Date?
    public var events: [PlaceEvent]
    public var distanceMeters: Double
    /// Auto-generated from the first and last tier-1 place ("İstanbul → Ordu"); the user
    /// may edit it (spec §9). `nil` until enough places are known.
    public var title: String?
    /// `nil` when route recording is off (spec 7.7).
    public var route: RouteTrace?

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date? = nil,
        events: [PlaceEvent] = [],
        distanceMeters: Double = 0,
        title: String? = nil,
        route: RouteTrace? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.events = events
        self.distanceMeters = distanceMeters
        self.title = title
        self.route = route
    }

    public var duration: TimeInterval {
        (endedAt ?? startedAt).timeIntervalSince(startedAt)
    }

    /// The `threadIdentifier` for this trip's notifications (spec 8.3: `trip-{tripID}`).
    public var notificationThread: String { "trip-\(id.uuidString)" }
}

/// End-of-trip rollup (spec §9, "Yolculuk özeti"). Counts are keyed by tier, not by a
/// hard-coded province/district split (spec K6). `highlights` is filled by F6 once the
/// place repository is wired.
public struct TripSummary: Sendable {
    public var countsByTier: [Tier: Int]
    public var settlementCount: Int
    public var distanceMeters: Double
    public var duration: TimeInterval
    public var highlights: [Place]

    public init(
        countsByTier: [Tier: Int] = [:],
        settlementCount: Int = 0,
        distanceMeters: Double = 0,
        duration: TimeInterval = 0,
        highlights: [Place] = []
    ) {
        self.countsByTier = countsByTier
        self.settlementCount = settlementCount
        self.distanceMeters = distanceMeters
        self.duration = duration
        self.highlights = highlights
    }

    /// Distinct places entered, per tier, from a trip's event list.
    public static func counts(from events: [PlaceEvent]) -> (byTier: [Tier: Int], settlements: Int) {
        var byTier: [Tier: Set<Int>] = [:]
        var settlements: Set<Int> = []
        for event in events {
            if let tier = event.place.tier {
                byTier[tier, default: []].insert(event.place.id)
            } else {
                settlements.insert(event.place.id)
            }
        }
        return (byTier.mapValues(\.count), settlements.count)
    }
}

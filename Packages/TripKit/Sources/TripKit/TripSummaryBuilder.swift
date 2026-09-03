//  TripSummaryBuilder.swift
//  TripKit
//
//  End-of-trip rollup and the auto-generated title (spec §9, P8).

import Foundation
import GeoData
import LocationEngine

public extension TripSummary {

    /// Build the summary for a finished trip. `resolvePlace` hydrates a `PlaceRef` into a
    /// `Place` (spec: `GeoData`'s `PlaceRepository`); events that don't resolve are
    /// simply left out of the highlights.
    static func make(from trip: Trip, resolvePlace: (PlaceRef) -> Place?) -> TripSummary {
        let (byTier, settlements) = counts(from: trip.events)

        let places = trip.events.map(\.place).compactMap(resolvePlace)
        let withPopulation = places.filter { $0.population != nil }
        let withElevation = places.filter { $0.elevationMeters != nil }

        var highlights: [Place] = []
        var seen = Set<PlaceRef>()
        func add(_ place: Place?) {
            guard let place, seen.insert(place.ref).inserted else { return }
            highlights.append(place)
        }
        add(withPopulation.max { $0.population! < $1.population! })     // biggest
        add(withPopulation.min { $0.population! < $1.population! })     // smallest
        add(withElevation.max { $0.elevationMeters! < $1.elevationMeters! })  // highest

        return TripSummary(
            countsByTier: byTier,
            settlementCount: settlements,
            distanceMeters: trip.distanceMeters,
            duration: trip.duration,
            highlights: highlights
        )
    }
}

public extension Trip {

    /// "İstanbul → Ordu" from the first and last tier-1 place. `nil` until at least one
    /// tier-1 place is known; a single tier-1 place yields just its name.
    static func autoTitle(
        from events: [PlaceEvent], resolveName: (PlaceRef) -> String?
    ) -> String? {
        let tier1Names = events
            .filter { $0.place.tier == .first }
            .compactMap { resolveName($0.place) }
        guard let first = tier1Names.first else { return nil }
        guard let last = tier1Names.last, last != first else { return first }
        return "\(first) → \(last)"
    }
}

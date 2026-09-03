//  Models.swift
//  LocationEngine
//
//  Value types for the presence pipeline (spec §7, §9). CoreLocation-free so the state
//  machine stays deterministically testable (spec 6.1 / P4).

import Foundation
import GeoData

/// One filtered location fix. The engine works only with these — never `CLLocation`
/// directly (spec P4: stay behind the seam).
public struct LocationSample: Sendable, Hashable {
    public let coordinate: Coordinate
    /// Metres. Negative means "unknown" (matches `CLLocation` semantics).
    public let horizontalAccuracy: Double
    /// Metres per second. Negative means "unknown".
    public let speed: Double
    public let timestamp: Date

    public init(
        coordinate: Coordinate,
        horizontalAccuracy: Double = 10,
        speed: Double = -1,
        timestamp: Date
    ) {
        self.coordinate = coordinate
        self.horizontalAccuracy = horizontalAccuracy
        self.speed = speed
        self.timestamp = timestamp
    }
}

/// Which independent state machine an event or state belongs to. The set is derived from
/// the pack's tiers plus settlement — never hard-coded (spec K6, §7.3).
public enum PresenceMachineKey: Hashable, Sendable {
    case tier(Tier)
    case settlement

    /// Ordering for deterministic event output: tiers ascending, settlement last.
    var sortRank: Int {
        switch self {
        case .tier(let t): return t.rawValue
        case .settlement: return Int.max
        }
    }
}

/// Emitted when a place is *confirmed* (spec 7.4 "[OLAY ÜRET]"). `enteredAt` /
/// `coordinate` mark the first fix inside the place, not the confirmation moment — the
/// honest answer to "when did I enter here".
public struct PlaceEvent: Identifiable, Sendable, Codable {
    public let id: UUID
    public let place: PlaceRef
    public let enteredAt: Date
    public let coordinate: Coordinate

    public init(id: UUID = UUID(), place: PlaceRef, enteredAt: Date, coordinate: Coordinate) {
        self.id = id
        self.place = place
        self.enteredAt = enteredAt
        self.coordinate = coordinate
    }

    /// `nil` for a settlement event.
    public var tier: Tier? { place.tier }
}

extension PlaceEvent: Equatable {
    /// Identity is the (place, entry) pair — the random `id` is ignored so events built
    /// in tests compare by meaning.
    public static func == (lhs: PlaceEvent, rhs: PlaceEvent) -> Bool {
        lhs.place == rhs.place
            && lhs.enteredAt == rhs.enteredAt
            && lhs.coordinate == rhs.coordinate
    }
}

/// Per-machine state (spec 7.3).
public enum PresenceState: Sendable, Equatable {
    case unknown
    case candidate(place: PlaceRef, since: Date, entryPoint: Coordinate)
    case confirmed(place: PlaceRef, since: Date)
    /// `since` is when the exit began; `confirmedSince` is the original entry time,
    /// restored verbatim if the traveller re-enters (spec 7.4: no event on re-entry).
    case exiting(place: PlaceRef, since: Date, confirmedSince: Date, exitPoint: Coordinate)

    public var place: PlaceRef? {
        switch self {
        case .unknown: return nil
        case .candidate(let p, _, _), .confirmed(let p, _), .exiting(let p, _, _, _): return p
        }
    }

    public var isConfirmed: Bool {
        if case .confirmed = self { return true }
        return false
    }
}

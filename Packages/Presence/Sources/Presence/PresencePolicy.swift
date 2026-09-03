//  PresencePolicy.swift
//  Presence
//
//  The event → surface matrix (spec 8.1). Given the user's sensitivity, decides which
//  surfaces an event reaches. Live Activity and the timeline always update; only the
//  push notification is gated by sensitivity.

import Foundation
import GeoData
import LocationEngine

/// How much the user wants to be told (spec 8.1). Default is `.tier2` — a notification
/// for each new province and district, not for every village.
public enum NotificationSensitivity: Int, Sendable, CaseIterable, Comparable, Codable {
    /// Provinces only (Turkey: il).
    case tier1 = 1
    /// + districts (ilçe).
    case tier2 = 2
    /// + settlements (village/town).
    case settlement = 3

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Which surfaces an event reaches.
public struct SurfaceRouting: Sendable, Equatable {
    public var updatesLiveActivity: Bool
    public var appendsToTimeline: Bool
    public var sendsPush: Bool

    public static let none = SurfaceRouting(
        updatesLiveActivity: false, appendsToTimeline: false, sendsPush: false
    )
}

public struct PresencePolicy: Sendable {
    public var sensitivity: NotificationSensitivity

    public init(sensitivity: NotificationSensitivity = .tier2) {
        self.sensitivity = sensitivity
    }

    /// The "rank" an event must clear to earn a push. Administrative events use their
    /// tier number; settlements sit at the deepest rank. A tier-1 event always clears
    /// (rank 1 ≤ any sensitivity). A future tier-3 country needs no change here.
    private func pushRank(for event: PlaceEvent) -> Int {
        event.place.tier?.rawValue ?? NotificationSensitivity.settlement.rawValue
    }

    public func routing(for event: PlaceEvent) -> SurfaceRouting {
        SurfaceRouting(
            updatesLiveActivity: true,
            appendsToTimeline: true,
            sendsPush: sensitivity.rawValue >= pushRank(for: event)
        )
    }
}

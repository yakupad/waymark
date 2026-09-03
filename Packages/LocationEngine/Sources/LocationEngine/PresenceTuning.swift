//  PresenceTuning.swift
//  LocationEngine
//
//  Every tunable in one struct (spec 7.5) — nothing hard-coded in the machine. The
//  debug menu (spec §10) mutates a copy of this live.

import Foundation

public struct PresenceTuning: Sendable, Equatable {
    /// Candidate → confirmed once dwelled this long (spec 7.5).
    public var confirmDwellTime: TimeInterval = 60
    /// …or once this far from the entry point (fast highway passes).
    public var confirmDwellDistance: Double = 2_000
    /// Hysteresis: must get this far past where the boundary was crossed before exit
    /// completes. Must differ from any entry threshold or GPS jitter loops forever.
    public var exitBufferDistance: Double = 750
    /// …and stay out this long.
    public var exitDwellTime: TimeInterval = 90
    /// A settlement counts as "here" within this radius (spec K4 — the roadside-sign feel).
    public var settlementRadius: Double = 1_500

    /// Consumed by `Presence` (F6), not the engine — kept here as the single home (7.5).
    public var regionCooldown: TimeInterval = 24 * 60 * 60
    /// Consumed by `Presence` (F6): hard cap regardless of logic bugs.
    public var maxNotificationsPerHour: Int = 6
    /// Consumed by `TripKit` (F8): < 3 m/s for this long ⇒ suggest the trip ended.
    public var staleTripTimeout: TimeInterval = 20 * 60

    public static let `default` = PresenceTuning()

    public init() {}
}

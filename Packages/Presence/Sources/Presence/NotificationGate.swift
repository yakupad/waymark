//  NotificationGate.swift
//  Presence
//
//  Guards the push channel (spec 7.5, 8.4). Three independent brakes:
//
//   1. cooldown      — same place, no repeat push within `regionCooldown` (24 h)
//   2. rate limit    — at most `maxNotificationsPerHour` (6) in any trailing hour;
//                      the safety valve that holds even if the logic upstream misfires
//   3. quiet hours   — no push in the user's configured window (default: disabled)
//
//  The gate only affects push. The Live Activity keeps updating through quiet hours
//  (spec 8.4) — that is the coordinator's job, not the gate's.

import Foundation
import GeoData
import LocationEngine

public struct QuietHours: Sendable, Equatable {
    /// Local hour [0, 23] the window opens, e.g. 23.
    public var startHour: Int
    /// Local hour [0, 23] the window closes, e.g. 7. May wrap past midnight.
    public var endHour: Int
    public var timeZone: TimeZone

    public init(startHour: Int, endHour: Int, timeZone: TimeZone = .current) {
        self.startHour = startHour
        self.endHour = endHour
        self.timeZone = timeZone
    }

    public func contains(_ date: Date) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let hour = calendar.component(.hour, from: date)
        if startHour == endHour { return false }
        if startHour < endHour {
            return hour >= startHour && hour < endHour
        }
        // wraps midnight (e.g. 23 → 7)
        return hour >= startHour || hour < endHour
    }
}

public struct NotificationGate: Sendable {

    public struct Config: Sendable {
        public var cooldown: TimeInterval = 24 * 60 * 60
        public var maxNotificationsPerHour: Int = 6
        /// `nil` ⇒ quiet hours disabled (spec 8.4 default).
        public var quietHours: QuietHours?

        public init() {}
    }

    public enum Decision: Sendable, Equatable {
        case allow
        case suppressedByCooldown
        case suppressedByRateLimit
        case suppressedByQuietHours
    }

    public var config: Config

    private var lastPushByPlace: [PlaceRef: Date] = [:]
    private var recentPushes: [Date] = []

    public init(config: Config = Config()) {
        self.config = config
    }

    /// Decide whether `event` may push at `now`. On `.allow` the gate records the push;
    /// suppressed events leave no trace, so a later legitimate push is not starved.
    public mutating func evaluate(_ event: PlaceEvent, now: Date) -> Decision {
        if let quietHours = config.quietHours, quietHours.contains(now) {
            return .suppressedByQuietHours
        }
        if let last = lastPushByPlace[event.place], now.timeIntervalSince(last) < config.cooldown {
            return .suppressedByCooldown
        }
        recentPushes.removeAll { now.timeIntervalSince($0) >= 3_600 }
        if recentPushes.count >= config.maxNotificationsPerHour {
            return .suppressedByRateLimit
        }

        lastPushByPlace[event.place] = now
        recentPushes.append(now)
        return .allow
    }

    public mutating func reset() {
        lastPushByPlace.removeAll()
        recentPushes.removeAll()
    }
}

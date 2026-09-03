//  SettingsStore.swift
//  waymark
//
//  User preferences (spec §10 "Ayarlar", §8.4, 7.5, 7.7). Backed by UserDefaults;
//  `@Observable` so screens react to changes.

import Foundation
import SwiftUI
import LocationEngine
import TripKit
import Presence

@MainActor
@Observable
final class SettingsStore {

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.sensitivity = Self.readSensitivity(defaults)
        self.quietHoursEnabled = defaults.bool(forKey: Keys.quietEnabled)
        self.quietStartHour = defaults.object(forKey: Keys.quietStart) as? Int ?? 23
        self.quietEndHour = defaults.object(forKey: Keys.quietEnd) as? Int ?? 7
        self.shareTrimMeters = defaults.object(forKey: Keys.trim) as? Double ?? 1_000
        self.tuning = .default
    }

    var sensitivity: NotificationSensitivity {
        didSet { defaults.set(sensitivity.rawValue, forKey: Keys.sensitivity) }
    }

    var quietHoursEnabled: Bool {
        didSet { defaults.set(quietHoursEnabled, forKey: Keys.quietEnabled) }
    }
    var quietStartHour: Int {
        didSet { defaults.set(quietStartHour, forKey: Keys.quietStart) }
    }
    var quietEndHour: Int {
        didSet { defaults.set(quietEndHour, forKey: Keys.quietEnd) }
    }

    /// Endpoint trim distance for share images (spec 7.7): 0 / 500 / 1000 / 2000.
    var shareTrimMeters: Double {
        didSet { defaults.set(shareTrimMeters, forKey: Keys.trim) }
    }

    /// Route-trace recording switch (spec 7.7). Default on.
    var recordRouteTrace: Bool {
        get { RouteTracePreference(defaults: defaults).isEnabled }
        set { RouteTracePreference(defaults: defaults).isEnabled = newValue }
    }

    /// Live-adjustable in the debug menu (spec 7.5); not persisted.
    var tuning: PresenceTuning

    var quietHours: QuietHours? {
        quietHoursEnabled
            ? QuietHours(startHour: quietStartHour, endHour: quietEndHour)
            : nil
    }

    var gateConfig: NotificationGate.Config {
        var config = NotificationGate.Config()
        config.cooldown = tuning.regionCooldown
        config.maxNotificationsPerHour = tuning.maxNotificationsPerHour
        config.quietHours = quietHours
        return config
    }

    private static func readSensitivity(_ defaults: UserDefaults) -> NotificationSensitivity {
        let raw = defaults.object(forKey: Keys.sensitivity) as? Int
        return raw.flatMap(NotificationSensitivity.init(rawValue:)) ?? .tier1
    }

    private enum Keys {
        static let sensitivity = "waymark.settings.sensitivity"
        static let quietEnabled = "waymark.settings.quietHoursEnabled"
        static let quietStart = "waymark.settings.quietStartHour"
        static let quietEnd = "waymark.settings.quietEndHour"
        static let trim = "waymark.settings.shareTrimMeters"
    }
}

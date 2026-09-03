//  PermissionsModel.swift
//  waymark
//
//  Progressive permission flow (spec §11): don't ask on first launch; ask for
//  "When In Use" when the user starts their first trip; ask for "Always" once a trip is
//  underway, with a plain explanation of what breaks without it; ask for notifications
//  when a trip first starts.

import Foundation
import SwiftUI
import CoreLocation
import UserNotifications
import LocationEngine

@MainActor
@Observable
final class PermissionsModel {

    private let env: AppEnvironment
    private let defaults: UserDefaults

    /// Shown as a dismissible card on the active-trip screen (spec §11 step 4).
    var showBackgroundUpgradeCard = false

    /// Screenshot / demo mode (`-waymarkScreen …`): skip the system prompts so the
    /// captures aren't covered by an alert.
    var demoMode = CommandLine.arguments.contains("-waymarkScreen")

    init(env: AppEnvironment, defaults: UserDefaults = .standard) {
        self.env = env
        self.defaults = defaults
    }

    var locationStatus: CLAuthorizationStatus {
        env.locationProvider.authorizationStatus
    }

    /// Called from `LiveTripController.start()`.
    func onTripStarted() {
        guard !demoMode else { return }
        // 1. Location — "When In Use" if still undetermined (system shows our string).
        if locationStatus == .notDetermined {
            env.locationProvider.requestAuthorization()
        }
        // 2. Notifications — request once, the first time a trip starts.
        if !defaults.bool(forKey: Keys.askedNotifications) {
            defaults.set(true, forKey: Keys.askedNotifications)
            Task { _ = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound]) }
        }
        // 3. Background upgrade — offer it a little into the trip, not immediately.
        scheduleBackgroundUpgradeCheck()
    }

    func onTripEnded() {
        showBackgroundUpgradeCard = false
    }

    func requestBackgroundUpgrade() {
        defaults.set(true, forKey: Keys.askedAlways)
        env.locationProvider.requestAuthorization()   // whenInUse -> always
        showBackgroundUpgradeCard = false
    }

    func dismissBackgroundUpgrade() {
        defaults.set(true, forKey: Keys.askedAlways)
        showBackgroundUpgradeCard = false
    }

    private func scheduleBackgroundUpgradeCheck() {
        guard !defaults.bool(forKey: Keys.askedAlways) else { return }
        Task {
            try? await Task.sleep(for: .seconds(25))
            if locationStatus == .authorizedWhenInUse,
               !defaults.bool(forKey: Keys.askedAlways) {
                showBackgroundUpgradeCard = true
            }
        }
    }

    private enum Keys {
        static let askedNotifications = "waymark.perm.askedNotifications"
        static let askedAlways = "waymark.perm.askedAlways"
    }
}

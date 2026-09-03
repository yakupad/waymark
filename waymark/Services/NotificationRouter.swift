//  NotificationRouter.swift
//  waymark
//
//  Handles the "Start a trip" action on the travel nudge notification (spec §11 F10b).

import Foundation
import UserNotifications

@MainActor
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationRouter()
    private override init() { super.init() }

    nonisolated static let travelNudgeCategory = "travel-nudge"
    nonisolated static let startTripAction = "START_TRIP"

    /// Call once from `App.init()` — before any notification can be delivered.
    func register() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let start = UNNotificationAction(
            identifier: Self.startTripAction,
            title: String(localized: "Start a trip"),
            options: [.foreground]
        )
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: Self.travelNudgeCategory,
                actions: [start],
                intentIdentifiers: [],
                options: []
            )
        ])
    }

    // Show the banner even if the app happens to be foregrounded.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == Self.startTripAction else { return }
        await MainActor.run { try? TripController.shared.start() }
    }
}

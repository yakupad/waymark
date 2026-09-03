//  NotificationRouter.swift
//  waymark
//
//  Handles the "Start a trip" action on the travel nudge notification (spec §11 F10b).

import Foundation
import UserNotifications

/// Plain `NSObject` — `UNUserNotificationCenterDelegate` is nonisolated and the
/// system calls it off the main thread, so everything that touches app state hops
/// explicitly.
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationRouter()
    private override init() { super.init() }

    static let travelNudgeCategory = "travel-nudge"
    static let startTripAction = "START_TRIP"

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

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Suppress crossing alerts while the app is open (the Live Activity and the
        // in-app list already show them); still surface the travel nudge.
        let isNudge = notification.request.content.categoryIdentifier == Self.travelNudgeCategory
        completionHandler(isNudge ? [.banner, .sound] : [])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let isStartAction = response.actionIdentifier == Self.startTripAction
        Task { @MainActor in
            if isStartAction { try? TripController.shared.start() }
            completionHandler()
        }
    }
}

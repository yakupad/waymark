//  UserNotificationSurface.swift
//  Presence
//
//  Production `NotificationSurface` over `UNUserNotificationCenter` (spec 8.3). Not
//  unit-tested (needs a real notification center / authorisation).

import Foundation
import UserNotifications

public actor UserNotificationSurface: NotificationSurface {

    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    @discardableResult
    public func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    public func post(_ notification: PlaceNotification) async {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.threadIdentifier = notification.threadIdentifier
        content.sound = .default
        if let link = notification.deepLink {
            content.userInfo["deepLink"] = link.absoluteString
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString, content: content, trigger: nil
        )
        try? await center.add(request)
    }
}

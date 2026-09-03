//  TravelNudge.swift
//  waymark
//
//  Spec §11 F10b: when the user is clearly on the road (car or bike) and hasn't
//  started a trip, post one gentle "start a trip?" notification. Opt-in — the
//  motion permission is only requested when the Settings toggle is turned on.
//
//  CoreMotion delivers updates while the app is running and for a grace period
//  after it's backgrounded; `checkRecentHistory()` (called on every foreground)
//  catches travel that happened while the app was suspended.

import Foundation
import CoreMotion
import UserNotifications
import LocationEngine

@MainActor
@Observable
final class TravelNudge {

    static let shared = TravelNudge()
    private init() {}

    private let manager = CMMotionActivityManager()
    private let queue = OperationQueue.main
    private let policy = TravelNudgePolicy()
    private var run = TravelRun()
    private var isEnabled = false
    private var isUpdating = false

    var isAvailable: Bool { CMMotionActivityManager.isActivityAvailable() }
    var authorization: CMAuthorizationStatus { CMMotionActivityManager.authorizationStatus() }

    // MARK: - Lifecycle

    /// Driven by the Settings toggle. Turning it on triggers the CoreMotion prompt.
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if enabled { startUpdates(); checkRecentHistory() }
        else { stopUpdates() }
    }

    /// Call when the app becomes active — CoreMotion stops feeding a suspended app,
    /// so re-arm the live stream and sweep the history since we last saw anything.
    func appBecameActive() {
        guard isEnabled else { return }
        startUpdates()
        checkRecentHistory()
    }

    func noteTripEnded() {
        Defaults.lastTripEnd = Date()
    }

    // MARK: -

    private func startUpdates() {
        guard isEnabled, isAvailable, !isUpdating else { return }
        isUpdating = true
        manager.startActivityUpdates(to: queue) { [weak self] activity in
            guard let self, let activity else { return }
            self.run.ingest(activity.travelMode, at: activity.startDate)
            self.evaluate()
        }
    }

    private func stopUpdates() {
        guard isUpdating else { return }
        manager.stopActivityUpdates()
        isUpdating = false
        run.reset()
    }

    private func checkRecentHistory() {
        guard isEnabled, isAvailable else { return }
        let now = Date()
        manager.queryActivityStarting(from: now.addingTimeInterval(-25 * 60), to: now, to: queue) {
            [weak self] activities, _ in
            guard let self, let activities, !activities.isEmpty else { return }
            self.run = TravelRun.run(over: activities.map { ($0.travelMode, $0.startDate) })
            self.evaluate()
        }
    }

    private func evaluate() {
        let now = Date()
        guard policy.shouldNudge(
            travellingSince: run.travellingSince,
            isTripActive: TripController.shared.isRunning,
            lastNudge: Defaults.lastNudge,
            lastTripEnd: Defaults.lastTripEnd,
            now: now
        ) else { return }
        Defaults.lastNudge = now
        Task { await postNudge() }
    }

    private func postNudge() async {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "On the road?")
        content.body = String(localized: "Start a trip and Waymark will note every place you pass.")
        content.categoryIdentifier = NotificationRouter.travelNudgeCategory
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        let request = UNNotificationRequest(
            identifier: "travel-nudge", content: content, trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    private enum Defaults {
        static var lastNudge: Date? {
            get { UserDefaults.standard.object(forKey: "waymark.nudge.last") as? Date }
            set { UserDefaults.standard.set(newValue, forKey: "waymark.nudge.last") }
        }
        static var lastTripEnd: Date? {
            get { UserDefaults.standard.object(forKey: "waymark.nudge.lastTripEnd") as? Date }
            set { UserDefaults.standard.set(newValue, forKey: "waymark.nudge.lastTripEnd") }
        }
    }
}

extension CMMotionActivity {
    var travelMode: TravelMode {
        guard confidence != .low else { return .unknown }
        if automotive { return .automotive }
        if cycling { return .cycling }
        if running { return .running }
        if walking { return .walking }
        if stationary { return .stationary }
        return .unknown
    }
}

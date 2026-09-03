//  PresenceCoordinator.swift
//  Presence
//
//  Routes presence events to the Live Activity and push channels per spec 8: applies
//  the sensitivity matrix (`PresencePolicy`), coalesces Live Activity updates to one
//  per 60 s (`UpdateCoalescer`), and gates push through cooldown / rate-limit / quiet
//  hours (`NotificationGate`).
//
//  An `actor` so the mutable gate/coalescer/tally stay consistent under concurrent
//  event delivery. Time comes from an injected `TimeSource` for deterministic tests.

import Foundation
import GeoData
import LocationEngine
import TripKit

/// Spec 6.3 seam. The App drives this from the trip lifecycle.
public protocol PresencePresenting: Sendable {
    func startActivity(for trip: Trip) async
    func update(with event: PlaceEvent) async
    func endActivity(summary: TripSummary) async
    func notify(_ event: PlaceEvent) async
}

public actor PresenceCoordinator: PresencePresenting {

    private let activity: any ActivitySurface
    private let notifications: any NotificationSurface
    private let places: any PlaceRepository
    private let copy: any NotificationCopy
    private let timeSource: any TimeSource
    private let language: String

    private var policy: PresencePolicy
    private var gate: NotificationGate
    private var coalescer: UpdateCoalescer

    // Running trip tally.
    private var thread = ""
    private var activityRunning = false
    private var visitedByTier: [Tier: Set<Int>] = [:]
    private var visitedSettlements: Set<Int> = []
    /// Deepest-rank place currently shown as the headline.
    private var headlinePlace: Place?
    private var headlineRank = Int.min
    private var headlineEnteredAt = Date.distantPast

    public init(
        activity: any ActivitySurface,
        notifications: any NotificationSurface,
        places: any PlaceRepository,
        copy: any NotificationCopy = DefaultNotificationCopy(),
        policy: PresencePolicy = PresencePolicy(),
        gate: NotificationGate = NotificationGate(),
        coalescer: UpdateCoalescer = UpdateCoalescer(),
        timeSource: any TimeSource = SystemTimeSource(),
        language: String = "en"
    ) {
        self.activity = activity
        self.notifications = notifications
        self.places = places
        self.copy = copy
        self.policy = policy
        self.gate = gate
        self.coalescer = coalescer
        self.timeSource = timeSource
        self.language = language
    }

    // MARK: - Configuration

    public func setSensitivity(_ sensitivity: NotificationSensitivity) {
        policy.sensitivity = sensitivity
    }

    public func setQuietHours(_ quietHours: QuietHours?) {
        gate.config.quietHours = quietHours
    }

    public func applyTuning(_ tuning: PresenceTuning) {
        gate.config.cooldown = tuning.regionCooldown
        gate.config.maxNotificationsPerHour = tuning.maxNotificationsPerHour
    }

    // MARK: - PresencePresenting

    public func startActivity(for trip: Trip) async {
        thread = trip.notificationThread
        visitedByTier.removeAll()
        visitedSettlements.removeAll()
        headlinePlace = nil
        headlineRank = .min
        headlineEnteredAt = .distantPast
        gate.reset()
        coalescer.reset()
        activityRunning = true
        await activity.start(makeState(), thread: thread)
    }

    public func update(with event: PlaceEvent) async {
        let routing = policy.routing(for: event)
        let place = try? places.place(for: event.place, language: language)

        record(event, place: place)

        if routing.updatesLiveActivity, activityRunning {
            if coalescer.enqueue(event, now: now) != nil {
                await activity.update(makeState())
            }
        }

        if routing.sendsPush, let place {
            await deliverPush(for: event, place: place)
        }
    }

    public func notify(_ event: PlaceEvent) async {
        guard let place = try? places.place(for: event.place, language: language) else { return }
        record(event, place: place)
        await deliverPush(for: event, place: place)
    }

    public func endActivity(summary: TripSummary) async {
        guard activityRunning else { return }
        if coalescer.drain(now: now) != nil {
            await activity.update(makeState())
        }
        await activity.end(makeState(summary: summary))
        activityRunning = false
    }

    /// Flush a coalesced Live Activity update whose 60 s window has elapsed. The App
    /// schedules a call to this at `pendingFlushDate`.
    public func flushPendingActivityUpdate() async {
        guard activityRunning, coalescer.flushIfDue(now: now) != nil else { return }
        await activity.update(makeState())
    }

    public var pendingFlushDate: Date? {
        coalescer.nextFlushDate
    }

    // MARK: - Internals

    private var now: Date { timeSource.now }

    private func deliverPush(for event: PlaceEvent, place: Place) async {
        guard gate.evaluate(event, now: now) == .allow else { return }
        let notification = copy.makeNotification(
            for: place, ref: event.place, thread: thread, language: language
        )
        await notifications.post(notification)
    }

    private func record(_ event: PlaceEvent, place: Place?) {
        if let tier = event.place.tier {
            visitedByTier[tier, default: []].insert(event.place.id)
        } else {
            visitedSettlements.insert(event.place.id)
        }
        // The headline is the most recently confirmed place. Deeper events (a settlement
        // inside the district you just entered) win within the same fix via `rank`, but
        // a coarser event from a *later* fix (crossing into a new province) still takes
        // over — the previous finer place is now stale and we get no exit event for it.
        let rank = event.place.tier?.rawValue ?? NotificationSensitivity.settlement.rawValue
        if let place {
            if event.enteredAt >= headlineEnteredAt || rank >= headlineRank {
                headlinePlace = place
                headlineRank = rank
                headlineEnteredAt = event.enteredAt
            }
        }
    }

    private func makeState(summary: TripSummary? = nil) -> LiveActivityState {
        let tierCounts: [Int: Int]
        let settlementCount: Int
        if let summary {
            tierCounts = Dictionary(
                uniqueKeysWithValues: summary.countsByTier.map { ($0.key.rawValue, $0.value) }
            )
            settlementCount = summary.settlementCount
        } else {
            tierCounts = Dictionary(
                uniqueKeysWithValues: visitedByTier.map { ($0.key.rawValue, $0.value.count) }
            )
            settlementCount = visitedSettlements.count
        }

        var headline = ""
        var hierarchy = ""
        var population: Int?
        if let place = headlinePlace {
            headline = place.nameLocal
            hierarchy = [place.nameLocal, place.parentName].compactMap { $0 }.joined(separator: ", ")
            population = place.population
        }

        return LiveActivityState(
            headline: headline,
            hierarchy: hierarchy,
            population: population,
            tierCounts: tierCounts,
            settlementCount: settlementCount,
            updatedAt: now
        )
    }
}

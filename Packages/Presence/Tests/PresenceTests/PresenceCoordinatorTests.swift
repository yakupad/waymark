//  PresenceCoordinatorTests.swift
//  PresenceTests
//
//  The coordinator end to end (spec 8): routing by sensitivity, 60 s coalescing,
//  push gating, quiet hours, trip lifecycle.

import Foundation
import Testing
import GeoData
import LocationEngine
import TripKit
@testable import Presence

struct PresenceCoordinatorTests {

    private func fixture(
        sensitivity: NotificationSensitivity = .tier1,
        gate: NotificationGate = NotificationGate()
    ) -> (PresenceCoordinator, FakePlaceRepository, RecordingActivitySurface, RecordingNotificationSurface, MutableTimeSource) {
        let repo = FakePlaceRepository()
        repo.add(makePlace(adminRef(1, 1), name: "Test İli A", population: 1_000_000))
        repo.add(makePlace(adminRef(2, 3), name: "İlçe C1", parent: "Test İli A", population: 50_000))
        repo.add(makePlace(settlementRef(7), name: "Köy Bir", parent: "İlçe C1", population: 800))
        let activity = RecordingActivitySurface()
        let notifications = RecordingNotificationSurface()
        let clock = MutableTimeSource(t0)
        let coord = makeCoordinator(
            repo: repo, activity: activity, notifications: notifications,
            sensitivity: sensitivity, gate: gate, clock: clock
        )
        return (coord, repo, activity, notifications, clock)
    }

    @Test func `startActivity opens the Live Activity with the trip thread`() async {
        let (coord, _, activity, _, _) = fixture()
        let trip = makeTrip()
        await coord.startActivity(for: trip)
        let started = await activity.started
        #expect(started.count == 1)
        #expect(started.first?.thread == trip.notificationThread)
    }

    @Test func `A tier-1 event updates the activity and pushes at default sensitivity`() async {
        let (coord, _, activity, notifications, _) = fixture()
        await coord.startActivity(for: makeTrip())
        await coord.update(with: event(adminRef(1, 1)))

        #expect(await activity.updates.count == 1)          // first event flushes now
        let posted = await notifications.posted
        #expect(posted.count == 1)
        #expect(posted.first?.title == "Test İli A'dasın")
        #expect(posted.first?.body.contains("nüfus") == true)
    }

    @Test func `Live Activity state carries the full chain and the province plate code`() async {
        let repo = FakePlaceRepository()
        let province = adminRef(1, 1)
        let district = adminRef(2, 3)
        let village = settlementRef(7)
        repo.add(makePlace(province, name: "Konya", population: 2_300_000, code: "42"))
        repo.add(makePlace(district, name: "Çumra", parent: "Konya", parentRef: province))
        repo.add(makePlace(village, name: "Toyçayırı", parent: "Çumra", population: 900, parentRef: district))
        let activity = RecordingActivitySurface()
        let clock = MutableTimeSource(t0)
        let coord = makeCoordinator(
            repo: repo, activity: activity, notifications: RecordingNotificationSurface(),
            sensitivity: .settlement, clock: clock
        )
        await coord.startActivity(for: makeTrip())
        await coord.update(with: event(village))

        let state = await activity.updates.last
        #expect(state?.headline == "Toyçayırı")
        #expect(state?.hierarchy == "Toyçayırı, Çumra, Konya")
        #expect(state?.provinceCode == "42")
    }

    @Test func `Push body embeds the plate on the province and the full chain`() async {
        let repo = FakePlaceRepository()
        let province = adminRef(1, 1)
        let district = adminRef(2, 3)
        repo.add(makePlace(province, name: "Konya", population: 2_300_000, code: "42"))
        repo.add(makePlace(district, name: "Çumra", parent: "Konya", population: 60_000, parentRef: province))
        let notifications = RecordingNotificationSurface()
        let clock = MutableTimeSource(t0)
        let coord = makeCoordinator(
            repo: repo, activity: RecordingActivitySurface(), notifications: notifications,
            sensitivity: .tier2, clock: clock
        )
        await coord.startActivity(for: makeTrip())
        await coord.update(with: event(district))

        let body = await notifications.posted.first?.body
        #expect(body?.hasPrefix("Konya 42 · ") == true)
    }

    @Test func `A tier-2 event does not push at tier-1 sensitivity but still updates the activity`() async {
        let (coord, _, activity, notifications, clock) = fixture(sensitivity: .tier1)
        await coord.startActivity(for: makeTrip())
        await coord.update(with: event(adminRef(1, 1), at: 0))
        clock.advance(by: 120)
        await coord.update(with: event(adminRef(2, 3), at: 120))

        #expect(await activity.updates.count == 2)
        #expect(await notifications.posted.count == 1)      // only the tier-1
    }

    @Test func `Raising sensitivity lets tier-2 events through`() async {
        let (coord, _, _, notifications, clock) = fixture(sensitivity: .tier2)
        await coord.startActivity(for: makeTrip())
        await coord.update(with: event(adminRef(1, 1), at: 0))
        clock.advance(by: 120)
        await coord.update(with: event(adminRef(2, 3), at: 120))
        #expect(await notifications.posted.count == 2)
    }

    @Test func `Updates inside the 60 s window are coalesced`() async {
        let (coord, _, activity, _, clock) = fixture(sensitivity: .settlement)
        await coord.startActivity(for: makeTrip())

        await coord.update(with: event(adminRef(1, 1), at: 0))     // flush #1
        clock.advance(by: 20)
        await coord.update(with: event(adminRef(2, 3), at: 20))    // held
        clock.advance(by: 20)
        await coord.update(with: event(settlementRef(7), at: 40))  // held
        #expect(await activity.updates.count == 1)

        clock.advance(by: 30)                                       // t0 + 70
        await coord.flushPendingActivityUpdate()
        #expect(await activity.updates.count == 2)
    }

    @Test func `The coalesced state carries the running tally and the deepest headline`() async {
        let (coord, _, activity, _, clock) = fixture(sensitivity: .settlement)
        await coord.startActivity(for: makeTrip())
        await coord.update(with: event(adminRef(1, 1), at: 0))
        clock.advance(by: 70)
        await coord.update(with: event(adminRef(2, 3), at: 70))
        clock.advance(by: 70)
        await coord.update(with: event(settlementRef(7), at: 140))

        let last = await activity.updates.last
        #expect(last?.headline == "Köy Bir")               // deepest rank wins
        #expect(last?.tierCounts[1] == 1)
        #expect(last?.tierCounts[2] == 1)
        #expect(last?.settlementCount == 1)
    }

    @Test func `Cooldown suppresses a second push for the same place`() async {
        let (coord, _, _, notifications, clock) = fixture(sensitivity: .settlement)
        await coord.startActivity(for: makeTrip())
        await coord.update(with: event(settlementRef(7), at: 0))
        clock.advance(by: 3_600)
        await coord.update(with: event(settlementRef(7), at: 3_600))
        #expect(await notifications.posted.count == 1)
    }

    @Test func `Quiet hours suppress the push but not the Live Activity`() async {
        var config = NotificationGate.Config()
        config.quietHours = QuietHours(startHour: 0, endHour: 24, timeZone: TimeZone(identifier: "UTC")!)
        let (coord, _, activity, notifications, _) = fixture(sensitivity: .tier1, gate: NotificationGate(config: config))
        await coord.startActivity(for: makeTrip())
        await coord.update(with: event(adminRef(1, 1)))

        #expect(await notifications.posted.isEmpty)
        #expect(await activity.updates.count == 1)
    }

    @Test func `notify pushes past the sensitivity matrix`() async {
        let (coord, _, _, notifications, _) = fixture(sensitivity: .tier1)
        await coord.startActivity(for: makeTrip())
        await coord.notify(event(adminRef(2, 3)))     // tier-2 would not push via update()
        #expect(await notifications.posted.count == 1)
    }

    @Test func `endActivity drains the backlog and ends with the summary`() async {
        let (coord, _, activity, _, clock) = fixture(sensitivity: .settlement)
        await coord.startActivity(for: makeTrip())
        await coord.update(with: event(adminRef(1, 1), at: 0))
        clock.advance(by: 10)
        await coord.update(with: event(adminRef(2, 3), at: 10))   // held

        let summary = TripSummary(
            countsByTier: [Tier(rawValue: 1): 3, Tier(rawValue: 2): 11],
            settlementCount: 4, distanceMeters: 750_000, duration: 36_000
        )
        await coord.endActivity(summary: summary)

        #expect(await activity.updates.count == 2)   // #1 first event, #2 drained backlog
        let ended = await activity.ended
        #expect(ended.count == 1)
        #expect(ended.first?.tierCounts[1] == 3)
        #expect(ended.first?.tierCounts[2] == 11)
        #expect(ended.first?.settlementCount == 4)
    }

    @Test func `Events before startActivity do not touch the Live Activity`() async {
        let (coord, _, activity, notifications, _) = fixture(sensitivity: .settlement)
        await coord.update(with: event(adminRef(1, 1)))
        #expect(await activity.updates.isEmpty)
        // push still works (it is not tied to the activity)
        #expect(await notifications.posted.count == 1)
    }
}

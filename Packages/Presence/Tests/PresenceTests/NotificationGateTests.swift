//  NotificationGateTests.swift
//  PresenceTests
//
//  Spec 7.5 / 8.4: cooldown, per-hour rate limit, quiet hours.

import Foundation
import Testing
import GeoData
import LocationEngine
@testable import Presence

struct NotificationGateTests {

    @Test func `First push for a place is allowed`() {
        var gate = NotificationGate()
        #expect(gate.evaluate(event(adminRef(1, 1)), now: t0) == .allow)
    }

    @Test func `Same place is suppressed within the cooldown, allowed after`() {
        var gate = NotificationGate()
        #expect(gate.evaluate(event(adminRef(1, 1)), now: t0) == .allow)
        #expect(gate.evaluate(event(adminRef(1, 1)), now: t0.addingTimeInterval(3_600)) == .suppressedByCooldown)
        #expect(gate.evaluate(event(adminRef(1, 1)), now: t0.addingTimeInterval(24 * 3_600 + 1)) == .allow)
    }

    @Test func `A different place is not affected by another's cooldown`() {
        var gate = NotificationGate()
        _ = gate.evaluate(event(adminRef(1, 1)), now: t0)
        #expect(gate.evaluate(event(adminRef(1, 2)), now: t0.addingTimeInterval(60)) == .allow)
    }

    @Test func `The per-hour rate limit is a hard ceiling`() {
        var gate = NotificationGate()
        var allowed = 0
        for i in 0..<10 {
            // distinct places so cooldown never fires
            if gate.evaluate(event(adminRef(1, i)), now: t0.addingTimeInterval(Double(i) * 60)) == .allow {
                allowed += 1
            }
        }
        #expect(allowed == 6)
    }

    @Test func `The rate-limit window slides`() {
        var gate = NotificationGate()
        for i in 0..<6 {
            _ = gate.evaluate(event(adminRef(1, i)), now: t0.addingTimeInterval(Double(i)))
        }
        #expect(gate.evaluate(event(adminRef(1, 99)), now: t0.addingTimeInterval(30)) == .suppressedByRateLimit)
        // an hour after the first six, the window has cleared
        #expect(gate.evaluate(event(adminRef(1, 99)), now: t0.addingTimeInterval(3_601)) == .allow)
    }

    @Test func `A suppressed push does not consume rate-limit budget`() {
        var config = NotificationGate.Config()
        config.quietHours = QuietHours(startHour: 0, endHour: 24, timeZone: TimeZone(identifier: "UTC")!)
        var gate = NotificationGate(config: config)
        // everything is quiet-suppressed
        for i in 0..<20 {
            #expect(gate.evaluate(event(adminRef(1, i)), now: t0) == .suppressedByQuietHours)
        }
        // lift quiet hours; full budget still available
        gate.config.quietHours = nil
        var allowed = 0
        for i in 0..<10 where gate.evaluate(event(adminRef(1, i)), now: t0.addingTimeInterval(Double(i))) == .allow {
            allowed += 1
        }
        #expect(allowed == 6)
    }

    @Test func `Quiet hours that wrap midnight`() {
        let quiet = QuietHours(startHour: 23, endHour: 7, timeZone: TimeZone(identifier: "UTC")!)
        // 2000-01-01 02:00 UTC
        let night = Date(timeIntervalSince1970: 946_692_000)
        // 2000-01-01 12:00 UTC
        let noon = Date(timeIntervalSince1970: 946_728_000)
        #expect(quiet.contains(night))
        #expect(!quiet.contains(noon))
    }

    @Test func `Quiet hours that do not wrap`() {
        let quiet = QuietHours(startHour: 9, endHour: 17, timeZone: TimeZone(identifier: "UTC")!)
        let noon = Date(timeIntervalSince1970: 946_728_000)   // 12:00 UTC
        let night = Date(timeIntervalSince1970: 946_692_000)  // 02:00 UTC
        #expect(quiet.contains(noon))
        #expect(!quiet.contains(night))
    }
}

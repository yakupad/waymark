//  PresencePolicyTests.swift
//  PresenceTests
//
//  Spec 8.1 matrix.

import Testing
import GeoData
import LocationEngine
@testable import Presence

struct PresencePolicyTests {

    @Test func `Live Activity and timeline always update, regardless of sensitivity`() {
        for sensitivity in NotificationSensitivity.allCases {
            let policy = PresencePolicy(sensitivity: sensitivity)
            for ref in [adminRef(1, 1), adminRef(2, 2), settlementRef(3)] {
                let routing = policy.routing(for: event(ref))
                #expect(routing.updatesLiveActivity)
                #expect(routing.appendsToTimeline)
            }
        }
    }

    @Test func `Tier-1 events always push`() {
        for sensitivity in NotificationSensitivity.allCases {
            let policy = PresencePolicy(sensitivity: sensitivity)
            #expect(policy.routing(for: event(adminRef(1, 1))).sendsPush)
        }
    }

    @Test func `Tier-2 events push only at sensitivity >= tier2`() {
        #expect(!PresencePolicy(sensitivity: .tier1).routing(for: event(adminRef(2, 5))).sendsPush)
        #expect(PresencePolicy(sensitivity: .tier2).routing(for: event(adminRef(2, 5))).sendsPush)
        #expect(PresencePolicy(sensitivity: .settlement).routing(for: event(adminRef(2, 5))).sendsPush)
    }

    @Test func `Settlement events push only at settlement sensitivity`() {
        #expect(!PresencePolicy(sensitivity: .tier1).routing(for: event(settlementRef(9))).sendsPush)
        #expect(!PresencePolicy(sensitivity: .tier2).routing(for: event(settlementRef(9))).sendsPush)
        #expect(PresencePolicy(sensitivity: .settlement).routing(for: event(settlementRef(9))).sendsPush)
    }

    @Test func `Default sensitivity is tier1`() {
        #expect(PresencePolicy().sensitivity == .tier1)
    }
}

//  UpdateCoalescerTests.swift
//  PresenceTests
//
//  Spec 8.2: at most one Live Activity update per 60 s; events inside the window merge.

import Foundation
import Testing
import LocationEngine
@testable import Presence

struct UpdateCoalescerTests {

    @Test func `The first event flushes immediately`() {
        var c = UpdateCoalescer(interval: 60)
        let batch = c.enqueue(event(adminRef(1, 1)), now: t0)
        #expect(batch?.count == 1)
    }

    @Test func `Events inside the window are held`() {
        var c = UpdateCoalescer(interval: 60)
        _ = c.enqueue(event(adminRef(1, 1)), now: t0)
        #expect(c.enqueue(event(adminRef(2, 2)), now: t0.addingTimeInterval(20)) == nil)
        #expect(c.enqueue(event(settlementRef(3)), now: t0.addingTimeInterval(40)) == nil)
        #expect(c.hasPending)
    }

    @Test func `The held batch flushes once the window elapses`() {
        var c = UpdateCoalescer(interval: 60)
        _ = c.enqueue(event(adminRef(1, 1)), now: t0)
        _ = c.enqueue(event(adminRef(2, 2)), now: t0.addingTimeInterval(20))
        _ = c.enqueue(event(settlementRef(3)), now: t0.addingTimeInterval(40))

        #expect(c.flushIfDue(now: t0.addingTimeInterval(59)) == nil)
        let batch = c.flushIfDue(now: t0.addingTimeInterval(61))
        #expect(batch?.count == 2)          // the two held events, merged
        #expect(!c.hasPending)
    }

    @Test func `A fresh event exactly at the window boundary flushes with the backlog`() {
        var c = UpdateCoalescer(interval: 60)
        _ = c.enqueue(event(adminRef(1, 1)), now: t0)
        _ = c.enqueue(event(adminRef(2, 2)), now: t0.addingTimeInterval(30))
        let batch = c.enqueue(event(settlementRef(3)), now: t0.addingTimeInterval(60))
        #expect(batch?.count == 2)
    }

    @Test func `drain force-flushes everything`() {
        var c = UpdateCoalescer(interval: 60)
        _ = c.enqueue(event(adminRef(1, 1)), now: t0)
        _ = c.enqueue(event(adminRef(2, 2)), now: t0.addingTimeInterval(10))
        let batch = c.drain(now: t0.addingTimeInterval(15))
        #expect(batch?.count == 1)
        #expect(c.drain(now: t0.addingTimeInterval(16)) == nil)   // nothing left
    }

    @Test func `nextFlushDate reports when the backlog is eligible`() {
        var c = UpdateCoalescer(interval: 60)
        _ = c.enqueue(event(adminRef(1, 1)), now: t0)
        #expect(c.nextFlushDate == nil)   // nothing pending
        _ = c.enqueue(event(adminRef(2, 2)), now: t0.addingTimeInterval(10))
        #expect(c.nextFlushDate == t0.addingTimeInterval(60))
    }
}

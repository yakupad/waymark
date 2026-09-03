//  UpdateCoalescer.swift
//  Presence
//
//  ActivityKit's update budget is limited, and at settlement sensitivity a dense route
//  produces a burst of events. This holds Live Activity updates to at most one per
//  `interval` (spec 8.2: 60 s); events that arrive inside the window are merged into
//  the next flush.

import Foundation
import LocationEngine

public struct UpdateCoalescer: Sendable {

    public var interval: TimeInterval
    private var lastFlush: Date?
    private var pending: [PlaceEvent] = []

    public init(interval: TimeInterval = 60) {
        self.interval = interval
    }

    public var hasPending: Bool { !pending.isEmpty }

    /// When the held events will be eligible to flush, or `nil` if nothing is waiting.
    public var nextFlushDate: Date? {
        guard !pending.isEmpty, let lastFlush else {
            return pending.isEmpty ? nil : .distantPast
        }
        return lastFlush.addingTimeInterval(interval)
    }

    /// Enqueue an event. Returns the batch to push to the Live Activity now, or `nil`
    /// if it should be held. The first event of a trip flushes immediately.
    public mutating func enqueue(_ event: PlaceEvent, now: Date) -> [PlaceEvent]? {
        pending.append(event)
        if let lastFlush, now.timeIntervalSince(lastFlush) < interval {
            return nil
        }
        return flush(now: now)
    }

    /// Flush whatever is pending if it is now due (call this when a scheduled timer
    /// fires). Returns `nil` if nothing is pending or the window has not elapsed.
    public mutating func flushIfDue(now: Date) -> [PlaceEvent]? {
        guard !pending.isEmpty else { return nil }
        if let lastFlush, now.timeIntervalSince(lastFlush) < interval {
            return nil
        }
        return flush(now: now)
    }

    /// Force-flush everything (trip end). Returns `nil` only if nothing is pending.
    public mutating func drain(now: Date) -> [PlaceEvent]? {
        guard !pending.isEmpty else { return nil }
        return flush(now: now)
    }

    private mutating func flush(now: Date) -> [PlaceEvent] {
        let batch = pending
        pending.removeAll(keepingCapacity: true)
        lastFlush = now
        return batch
    }

    public mutating func reset() {
        pending.removeAll()
        lastFlush = nil
    }
}

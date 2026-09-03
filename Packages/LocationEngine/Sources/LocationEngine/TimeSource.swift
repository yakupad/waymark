//  TimeSource.swift
//  LocationEngine
//
//  Injectable wall clock (spec P4: "Zaman için enjekte edilebilir bir Clock kullan ki
//  testler deterministik olsun"). The state machine times off sample timestamps; this
//  source is only for "is this fix stale?" (spec 7.2) and, later, the stale-trip check.

import Foundation

public protocol TimeSource: Sendable {
    var now: Date { get }
}

public struct SystemTimeSource: TimeSource {
    public init() {}
    public var now: Date { Date() }
}

/// Test / replay clock. `GPXReplayer` advances it to each fix's timestamp so the
/// sample-age filter passes on historical traces.
public final class MutableTimeSource: TimeSource, @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    public init(_ start: Date = Date(timeIntervalSince1970: 0)) {
        current = start
    }

    public var now: Date {
        lock.lock(); defer { lock.unlock() }
        return current
    }

    public func advance(to date: Date) {
        lock.lock(); defer { lock.unlock() }
        if date > current { current = date }
    }

    public func advance(by interval: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        current += interval
    }
}

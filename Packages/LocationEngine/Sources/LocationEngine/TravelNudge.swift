//  TravelNudge.swift
//  LocationEngine
//
//  Pure logic for the "you seem to be travelling — start a trip?" nudge (spec §11
//  F10b). The app feeds `CoreMotion` activity in; this decides whether to nudge.
//  No CoreMotion import here so it stays unit-testable.

import Foundation

/// A coarse travel mode, mapped from `CMMotionActivity` by the app layer.
public enum TravelMode: Sendable, Equatable {
    case automotive
    case cycling
    case walking
    case running
    case stationary
    case unknown
}

public extension TravelMode {
    var isTravelling: Bool { self == .automotive || self == .cycling }
    /// The traveller has clearly left the vehicle — end any pending "travelling" run.
    var endsTravel: Bool { self == .walking || self == .running }
}

/// Tracks how long the current uninterrupted stretch of vehicle/bike travel has
/// lasted. A brief `stationary` reading (a red light, a stop) doesn't break it.
public struct TravelRun: Sendable, Equatable {
    /// A `stationary` gap longer than this ends the run.
    public var stationaryGrace: TimeInterval = 3 * 60

    public private(set) var travellingSince: Date?
    private var lastTravelSample: Date?

    public init(stationaryGrace: TimeInterval = 3 * 60) {
        self.stationaryGrace = stationaryGrace
    }

    public mutating func ingest(_ mode: TravelMode, at time: Date) {
        if mode.isTravelling {
            if travellingSince == nil { travellingSince = time }
            lastTravelSample = time
        } else if mode.endsTravel {
            reset()
        } else if mode == .stationary {
            if let last = lastTravelSample, time.timeIntervalSince(last) > stationaryGrace {
                reset()
            }
        }
        // .unknown: leave the run as-is.
    }

    public mutating func reset() {
        travellingSince = nil
        lastTravelSample = nil
    }

    /// Replay a batch of history (oldest first), e.g. from `queryActivityStarting`.
    public static func run(over samples: [(mode: TravelMode, at: Date)]) -> TravelRun {
        var run = TravelRun()
        for s in samples.sorted(by: { $0.at < $1.at }) { run.ingest(s.mode, at: s.at) }
        return run
    }
}

/// Decides whether to post the nudge, given the current travel run and recent history.
public struct TravelNudgePolicy: Sendable, Equatable {
    /// Must have been travelling at least this long.
    public var minSustained: TimeInterval = 4 * 60
    /// Don't nudge again within this window.
    public var cooldown: TimeInterval = 90 * 60
    /// A trip that just ended was ended on purpose — stay quiet for a while.
    public var postTripQuiet: TimeInterval = 30 * 60

    public init() {}

    public func shouldNudge(
        travellingSince: Date?,
        isTripActive: Bool,
        lastNudge: Date?,
        lastTripEnd: Date?,
        now: Date
    ) -> Bool {
        guard !isTripActive else { return false }
        guard let since = travellingSince,
              now.timeIntervalSince(since) >= minSustained else { return false }
        if let last = lastNudge, now.timeIntervalSince(last) < cooldown { return false }
        if let end = lastTripEnd, now.timeIntervalSince(end) < postTripQuiet { return false }
        return true
    }
}

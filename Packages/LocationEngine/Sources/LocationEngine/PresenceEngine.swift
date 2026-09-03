//  PresenceEngine.swift
//  LocationEngine
//
//  Orchestrates the presence pipeline (spec §7): filter each fix (7.2), resolve it
//  (GeoData), then step every independent state machine (7.3–7.4) and collect the
//  confirmation events.
//
//  The machine set grows from the data (spec K6): a tier machine is created the first
//  time a resolution reports that tier, and a settlement machine always exists. A
//  three-tier country just makes one more machine appear — no code change.
//
//  Thread-safe via a lock so a `LocationProviding` on the main thread and callers on
//  other threads can share one engine.

import Foundation
import GeoData

public final class PresenceEngine: @unchecked Sendable {

    private let resolver: any GeoResolving
    private let tuning: PresenceTuning
    private let timeSource: any TimeSource

    private let lock = NSLock()
    private var filter: SampleFilter
    private var machines: [PresenceMachineKey: PresenceMachine] = [:]
    private var lastRejectionValue: SampleFilter.Rejection?

    public init(
        resolver: any GeoResolving,
        tuning: PresenceTuning = .default,
        timeSource: any TimeSource = SystemTimeSource(),
        filterConfig: SampleFilter.Config = .init()
    ) {
        self.resolver = resolver
        self.tuning = tuning
        self.timeSource = timeSource
        self.filter = SampleFilter(config: filterConfig)
        self.machines[.settlement] = PresenceMachine(key: .settlement, tuning: tuning)
    }

    // MARK: - Feeding fixes

    /// Feed one fix. Returns any events it confirmed, ordered tier-ascending then
    /// settlement. A filtered-out or unresolvable fix returns `[]`.
    @discardableResult
    public func ingest(_ sample: LocationSample) -> [PlaceEvent] {
        lock.lock()
        defer { lock.unlock() }

        switch filter.accept(sample, now: timeSource.now) {
        case .failure(let rejection):
            lastRejectionValue = rejection
            return []
        case .success(let fix):
            let resolution = (try? resolver.resolve(coordinate: fix.coordinate)) ?? .empty
            ensureMachines(for: resolution)

            let settlementRef = matchedSettlement(in: resolution)

            var events: [PlaceEvent] = []
            for key in machines.keys {
                let matched: PlaceRef?
                switch key {
                case .tier(let tier): matched = resolution.administrative[tier]
                case .settlement: matched = settlementRef
                }
                var machine = machines[key]!
                if let event = machine.step(
                    matchedRef: matched, coordinate: fix.coordinate, timestamp: fix.timestamp
                ) {
                    events.append(event)
                }
                machines[key] = machine
            }
            events.sort { rank($0) < rank($1) }
            return events
        }
    }

    /// Feed a whole trace, returning the flat event list in order.
    @discardableResult
    public func ingest(_ samples: [LocationSample]) -> [PlaceEvent] {
        samples.flatMap { ingest($0) }
    }

    // MARK: - Introspection (debug menu, tests)

    public var states: [PresenceMachineKey: PresenceState] {
        lock.lock(); defer { lock.unlock() }
        return machines.mapValues(\.state)
    }

    public func state(for key: PresenceMachineKey) -> PresenceState? {
        lock.lock(); defer { lock.unlock() }
        return machines[key]?.state
    }

    public var lastRejection: SampleFilter.Rejection? {
        lock.lock(); defer { lock.unlock() }
        return lastRejectionValue
    }

    public func reset() {
        lock.lock(); defer { lock.unlock() }
        filter.reset()
        lastRejectionValue = nil
        for key in machines.keys {
            machines[key]?.reset()
        }
    }

    // MARK: - Internals (call under lock)

    private func ensureMachines(for resolution: PlaceResolution) {
        for tier in resolution.administrative.keys where machines[.tier(tier)] == nil {
            machines[.tier(tier)] = PresenceMachine(key: .tier(tier), tuning: tuning)
        }
    }

    private func matchedSettlement(in resolution: PlaceResolution) -> PlaceRef? {
        guard
            let ref = resolution.settlement,
            let distance = resolution.settlementDistanceMeters,
            distance <= tuning.settlementRadius
        else { return nil }
        return ref
    }

    private func rank(_ event: PlaceEvent) -> Int {
        event.place.tier?.rawValue ?? Int.max
    }
}

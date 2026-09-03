//  PresenceMachine.swift
//  LocationEngine
//
//  One independent presence state machine (spec 7.3–7.4). Every tier and settlement
//  runs its own; they never interact (spec 7.3). The machine is fed, per fix, the place
//  it currently matches at its level (`nil` = matches nothing) and decides transitions
//  and whether to emit a confirmation event.

import Foundation
import GeoData

struct PresenceMachine {
    let key: PresenceMachineKey
    var tuning: PresenceTuning
    private(set) var state: PresenceState = .unknown

    init(key: PresenceMachineKey, tuning: PresenceTuning) {
        self.key = key
        self.tuning = tuning
    }

    /// Advance the machine by one fix.
    /// - Parameters:
    ///   - matchedRef: the place matched at this machine's level, or `nil`.
    ///   - coordinate: the fix location.
    ///   - timestamp: the fix time — all dwell / exit timing is measured off this
    ///     (not a wall clock), so replays at any speed are deterministic.
    /// - Returns: a `PlaceEvent` if this fix confirmed a place.
    mutating func step(
        matchedRef: PlaceRef?, coordinate: Coordinate, timestamp: Date
    ) -> PlaceEvent? {
        switch state {
        case .unknown:
            if let ref = matchedRef {
                state = .candidate(place: ref, since: timestamp, entryPoint: coordinate)
            }
            return nil

        case .candidate(let place, let since, let entryPoint):
            guard let ref = matchedRef else {
                state = .unknown
                return nil
            }
            if ref != place {
                // Moved straight into a different place — restart the dwell there.
                state = .candidate(place: ref, since: timestamp, entryPoint: coordinate)
                return nil
            }
            let dwelledLongEnough = timestamp.timeIntervalSince(since) >= tuning.confirmDwellTime
            let travelledFarEnough =
                Haversine.distance(entryPoint, coordinate) >= tuning.confirmDwellDistance
            guard dwelledLongEnough || travelledFarEnough else { return nil }
            state = .confirmed(place: place, since: since)
            return PlaceEvent(place: place, enteredAt: since, coordinate: entryPoint)

        case .confirmed(let place, let since):
            if matchedRef == place { return nil }
            state = .exiting(
                place: place, since: timestamp, confirmedSince: since, exitPoint: coordinate
            )
            return nil

        case .exiting(let place, let exitingSince, let confirmedSince, let exitPoint):
            if matchedRef == place {
                // Back inside before the exit completed — never really left (spec 7.4).
                state = .confirmed(place: place, since: confirmedSince)
                return nil
            }
            let farEnough =
                Haversine.distance(exitPoint, coordinate) >= tuning.exitBufferDistance
            let longEnough =
                timestamp.timeIntervalSince(exitingSince) >= tuning.exitDwellTime
            guard farEnough && longEnough else { return nil }
            // Exit complete. Re-run this same fix from `unknown` so a new candidate can
            // start immediately if we're already inside somewhere else.
            state = .unknown
            return step(matchedRef: matchedRef, coordinate: coordinate, timestamp: timestamp)
        }
    }

    mutating func reset() {
        state = .unknown
    }
}

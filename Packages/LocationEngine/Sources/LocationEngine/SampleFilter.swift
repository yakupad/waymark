//  SampleFilter.swift
//  LocationEngine
//
//  Sample filtering (spec 7.2). A fix is dropped when its accuracy is poor, its
//  timestamp is stale, or it implies a physically impossible jump from the last
//  accepted fix. Stateful — keeps the last accepted fix for the speed check.

import Foundation
import GeoData

public struct SampleFilter: Sendable {

    public struct Config: Sendable, Equatable {
        /// Reject `horizontalAccuracy > this` or `< 0` (spec 7.2).
        public var maxHorizontalAccuracy: Double = 200
        /// Reject a fix older than this relative to `now` (spec 7.2).
        public var maxSampleAge: TimeInterval = 30
        /// Reject if the implied speed from the last accepted fix exceeds this
        /// (spec 7.2: 60 m/s ≈ 216 km/h).
        public var maxSpeedMetersPerSecond: Double = 60

        public init() {}
    }

    public enum Rejection: String, Error, Sendable, Equatable {
        case poorAccuracy
        case staleTimestamp
        case outOfOrder
        case impossibleJump
    }

    public var config: Config
    private var lastAccepted: LocationSample?

    public init(config: Config = Config()) {
        self.config = config
    }

    public var lastAcceptedSample: LocationSample? { lastAccepted }

    public mutating func accept(
        _ sample: LocationSample, now: Date
    ) -> Result<LocationSample, Rejection> {
        if sample.horizontalAccuracy < 0 || sample.horizontalAccuracy > config.maxHorizontalAccuracy {
            return .failure(.poorAccuracy)
        }
        if now.timeIntervalSince(sample.timestamp) > config.maxSampleAge {
            return .failure(.staleTimestamp)
        }

        if let last = lastAccepted {
            let dt = sample.timestamp.timeIntervalSince(last.timestamp)
            if dt < 0 {
                return .failure(.outOfOrder)
            }
            if dt == 0 {
                // Same instant as the last accepted fix — nothing new to learn.
                return .failure(.outOfOrder)
            }
            let metres = Haversine.distance(last.coordinate, sample.coordinate)
            if metres / dt > config.maxSpeedMetersPerSecond {
                return .failure(.impossibleJump)
            }
        }

        lastAccepted = sample
        return .success(sample)
    }

    public mutating func reset() {
        lastAccepted = nil
    }
}

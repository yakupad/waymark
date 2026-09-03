//  RouteTracePreference.swift
//  TripKit
//
//  The "Rota izini kaydet" switch (spec 7.7). Default: on. Stored in `UserDefaults` so
//  it survives launches without touching the trip store.

import Foundation

public struct RouteTracePreference {

    public static let defaultsKey = "waymark.trip.recordRouteTrace"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Whether new trips record a route trace. Defaults to `true` when unset (spec 7.7).
    public var isEnabled: Bool {
        get {
            defaults.object(forKey: Self.defaultsKey) as? Bool ?? true
        }
        nonmutating set {
            defaults.set(newValue, forKey: Self.defaultsKey)
        }
    }
}

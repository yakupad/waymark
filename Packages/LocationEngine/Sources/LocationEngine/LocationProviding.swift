//  LocationProviding.swift
//  LocationEngine
//
//  The CoreLocation seam (spec 6.3). The engine never touches `CLLocationManager`
//  directly — tests substitute a fake provider and drive the state machine with
//  synthetic fixes (spec P4).

import Foundation
import CoreLocation
import GeoData

/// CoreLocation configuration for a trip (spec 7.1). Defaults are the spec's values.
public struct TrackingConfiguration: Sendable {
    public var desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyHundredMeters
    /// 100 m is for the route line; detection would be fine at 500 m (spec 7.1).
    public var distanceFilter: CLLocationDistance = 100
    public var allowsBackgroundLocationUpdates = true
    /// Deliberately off — we manage pausing ourselves (spec 7.1 / 7.5).
    public var pausesLocationUpdatesAutomatically = false
    public var activityType: CLActivityType = .automotiveNavigation
    public var showsBackgroundLocationIndicator = true

    public init() {}
}

/// `@MainActor` because every conforming provider wraps CoreLocation, which is
/// main-thread bound. The pure state machine does not depend on this seam.
@MainActor
public protocol LocationProvidingDelegate: AnyObject {
    func locationProvider(_ provider: any LocationProviding, didUpdate sample: LocationSample)
    func locationProvider(_ provider: any LocationProviding, didFailWith error: any Error)
    func locationProvider(
        _ provider: any LocationProviding, didChangeAuthorization status: CLAuthorizationStatus
    )
}

public extension LocationProvidingDelegate {
    func locationProvider(_ provider: any LocationProviding, didFailWith error: any Error) {}
    func locationProvider(
        _ provider: any LocationProviding, didChangeAuthorization status: CLAuthorizationStatus
    ) {}
}

@MainActor
public protocol LocationProviding: AnyObject {
    var delegate: LocationProvidingDelegate? { get set }
    func startTracking(configuration: TrackingConfiguration)
    func stopTracking()
    var authorizationStatus: CLAuthorizationStatus { get }
    /// Progressive request (spec §11): asks for "When In Use" if undetermined, then
    /// "Always" once "When In Use" is granted. No-op for fakes.
    func requestAuthorization()
}

public extension LocationProviding {
    func requestAuthorization() {}
}

public extension LocationSample {
    /// Build a sample from a `CLLocation`. `speed` is carried through but the engine
    /// derives its own speed for the impossible-jump check (spec 7.2).
    init(_ location: CLLocation) {
        self.init(
            coordinate: Coordinate(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            ),
            horizontalAccuracy: location.horizontalAccuracy,
            speed: location.speed,
            timestamp: location.timestamp
        )
    }
}

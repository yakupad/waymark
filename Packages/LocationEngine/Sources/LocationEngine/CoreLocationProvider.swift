//  CoreLocationProvider.swift
//  LocationEngine
//
//  The production `LocationProviding` — a thin `CLLocationManager` wrapper (spec 6.1,
//  7.1). Not unit-tested (needs a device / authorisation); the engine is exercised
//  through synthetic fixes instead.

import Foundation
import CoreLocation

@MainActor
public final class CoreLocationProvider: NSObject, LocationProviding {

    public weak var delegate: LocationProvidingDelegate?

    private let manager: CLLocationManager

    public override init() {
        manager = CLLocationManager()
        super.init()
        manager.delegate = self
    }

    public var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    public func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    public func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }

    public func requestAuthorization() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        default:
            break
        }
    }

    /// True only when the app actually declares the `location` background mode. Setting
    /// `allowsBackgroundLocationUpdates = true` without it is a hard `CLLocationManager`
    /// crash (`CLClientIsBackgroundable`), so we gate on it.
    private static let backgroundLocationAvailable: Bool = {
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]
        return modes?.contains("location") ?? false
    }()

    public func startTracking(configuration: TrackingConfiguration) {
        manager.desiredAccuracy = configuration.desiredAccuracy
        manager.distanceFilter = configuration.distanceFilter
        manager.activityType = configuration.activityType
        manager.pausesLocationUpdatesAutomatically = configuration.pausesLocationUpdatesAutomatically
        #if os(iOS) || os(watchOS)
        if configuration.allowsBackgroundLocationUpdates, Self.backgroundLocationAvailable {
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = configuration.showsBackgroundLocationIndicator
        }
        #endif
        manager.startUpdatingLocation()
    }

    public func stopTracking() {
        manager.stopUpdatingLocation()
    }
}

extension CoreLocationProvider: @preconcurrency CLLocationManagerDelegate {

    public func locationManager(
        _ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]
    ) {
        for location in locations {
            delegate?.locationProvider(self, didUpdate: LocationSample(location))
        }
    }

    public func locationManager(
        _ manager: CLLocationManager, didFailWithError error: any Error
    ) {
        delegate?.locationProvider(self, didFailWith: error)
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        delegate?.locationProvider(self, didChangeAuthorization: manager.authorizationStatus)
    }
}

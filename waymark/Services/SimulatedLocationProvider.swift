//  SimulatedLocationProvider.swift
//  waymark
//
//  A `LocationProviding` for the simulator and the debug menu (spec §10: "sahte konum
//  enjekte etme, GPX oynatma"). On `startTracking` it plays a built-in demo drive so the
//  app is usable without a device.
//
//  Simulated time is decoupled from wall-clock: the provider ticks every `tickInterval`
//  seconds of real time but advances `clock` by `spacing` seconds of *simulated* time
//  per fix, and stamps each sample from `clock`. `LiveTripController` feeds that same
//  clock to the `PresenceEngine`, so the sample-age and impossible-jump filters
//  (spec 7.2) see a coherent timeline.

import Foundation
import CoreLocation
import GeoData
import LocationEngine

@MainActor
final class SimulatedLocationProvider: LocationProviding {

    weak var delegate: (any LocationProvidingDelegate)?
    var authorizationStatus: CLAuthorizationStatus = .authorizedAlways

    /// Shared with the engine so filters see one timeline.
    let clock = MutableTimeSource(Date())

    private var timer: Timer?
    private var queue: [Coordinate] = []
    private var spacing: TimeInterval = 45
    private var index = 0
    var tickInterval: TimeInterval = 0.4

    func startTracking(configuration: TrackingConfiguration) {
        if queue.isEmpty {
            load(DemoRoute.acrossProvinces, spacing: 40)
        }
        resume()
    }

    func stopTracking() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Debug controls

    /// Emit one fix immediately (debug menu "inject fake location").
    func inject(_ coordinate: Coordinate) {
        clock.advance(by: spacing)
        delegate?.locationProvider(self, didUpdate: LocationSample(
            coordinate: coordinate, horizontalAccuracy: 8, speed: -1, timestamp: clock.now
        ))
    }

    /// Replace the queued track (debug menu "GPX playback" / demo).
    func load(_ coordinates: [Coordinate], spacing: TimeInterval) {
        queue = coordinates
        self.spacing = spacing
        index = 0
    }

    // MARK: -

    private func resume() {
        timer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        self.timer = timer
    }

    private func tick() {
        guard index < queue.count else {
            stopTracking()
            return
        }
        let coordinate = queue[index]
        index += 1
        clock.advance(by: spacing)
        delegate?.locationProvider(self, didUpdate: LocationSample(
            coordinate: coordinate, horizontalAccuracy: 8, speed: -1, timestamp: clock.now
        ))
    }
}

/// A short synthetic drive over the bundled pack's geometry (the F1 fixture — real
/// Turkey data lands with F1), so the simulator shows a live trip out of the box.
/// Fixes are ~1.1 km apart (under the 2 km segment-gap threshold) with a gentle wave so
/// the route line and previews look like a real drive, not a ruler.
enum DemoRoute {
    static let acrossProvinces: [Coordinate] = stride(from: 31.5, through: 34.3, by: 0.012)
        .map { lon in
            Coordinate(latitude: 39.0 + 0.05 * sin((lon - 31.5) * 2.2), longitude: lon)
        }
}

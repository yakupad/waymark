//  TestSupport.swift
//  LocationEngineTests

import Foundation
import Testing
import GeoData
@testable import LocationEngine

let epoch = Date(timeIntervalSince1970: 1_700_000_000)

func coord(_ lat: Double, _ lon: Double) -> Coordinate {
    Coordinate(latitude: lat, longitude: lon)
}

/// A run of fixes at one spot, `count` of them spaced `interval` apart.
func dwell(
    at c: Coordinate, from start: Date, count: Int, interval: TimeInterval = 30,
    accuracy: Double = 10
) -> [LocationSample] {
    (0..<count).map { i in
        LocationSample(
            coordinate: c, horizontalAccuracy: accuracy, speed: -1,
            timestamp: start.addingTimeInterval(Double(i) * interval)
        )
    }
}

/// Straight-line travel between two coordinates at a constant, filter-safe speed
/// (spec 7.2 caps at 60 m/s). Excludes the start point, includes the end.
func travel(
    from a: Coordinate, to b: Coordinate, startingAt start: Date,
    speed: Double = 30, interval: TimeInterval = 30
) -> [LocationSample] {
    let metres = Haversine.distance(a, b)
    let duration = max(interval, metres / speed)
    let steps = max(1, Int((duration / interval).rounded(.up)))
    return (1...steps).map { i in
        let f = Double(i) / Double(steps)
        return LocationSample(
            coordinate: Coordinate(
                latitude: a.latitude + (b.latitude - a.latitude) * f,
                longitude: a.longitude + (b.longitude - a.longitude) * f
            ),
            horizontalAccuracy: 10, speed: -1,
            timestamp: start.addingTimeInterval(duration * f)
        )
    }
}

func fixturePackPath() throws -> String {
    let url = try #require(
        Bundle.module.url(forResource: "tr", withExtension: "pack"),
        "fixture tr.pack missing from the LocationEngine test bundle"
    )
    return url.path
}

func gpxURL(_ name: String) throws -> URL {
    try #require(
        Bundle.module.url(forResource: name, withExtension: "gpx", subdirectory: "gpx"),
        "\(name).gpx missing from the test bundle"
    )
}

/// The fixture resolver — `SQLiteGeoResolver` is both `GeoResolving` and `PlaceRepository`.
func fixtureResolver() throws -> SQLiteGeoResolver {
    try SQLiteGeoResolver(path: try fixturePackPath())
}

extension Array where Element == PlaceEvent {
    func ids(tier: Tier) -> [Int] {
        filter { $0.place.tier == tier }.map(\.place.id)
    }
    var settlementIDs: [Int] {
        filter { $0.place.kind == .settlement }.map(\.place.id)
    }
}

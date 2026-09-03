//  HaversineTests.swift
//  GeoDataTests

import Foundation
import Testing
@testable import GeoData

struct HaversineTests {

    @Test func `Distance between identical points is zero`() {
        let p = Coordinate(latitude: 39.92, longitude: 32.85)
        #expect(Haversine.distance(p, p) == 0)
    }

    @Test func `One degree of longitude at the equator is about 111.2 km`() {
        let d = Haversine.distance(
            Coordinate(latitude: 0, longitude: 0),
            Coordinate(latitude: 0, longitude: 1)
        )
        #expect(abs(d - 111_195) < 50)
    }

    @Test func `One degree of latitude is about 111.2 km anywhere`() {
        let d = Haversine.distance(
            Coordinate(latitude: 39, longitude: 32),
            Coordinate(latitude: 40, longitude: 32)
        )
        #expect(abs(d - 111_195) < 50)
    }

    @Test func `Known city pair: Ankara to Istanbul is about 350 km`() {
        let ankara = Coordinate(latitude: 39.9334, longitude: 32.8597)
        let istanbul = Coordinate(latitude: 41.0082, longitude: 28.9784)
        let d = Haversine.distance(ankara, istanbul)
        #expect(d > 340_000 && d < 360_000)
    }

    @Test func `bbox degree helpers widen with latitude`() {
        let atEquator = Haversine.longitudeDegrees(forMeters: 1_000, atLatitude: 0)
        let atForty = Haversine.longitudeDegrees(forMeters: 1_000, atLatitude: 40)
        #expect(atForty > atEquator)
        // latitude spacing is constant
        #expect(abs(Haversine.latitudeDegrees(forMeters: 111_195) - 1) < 0.01)
    }
}

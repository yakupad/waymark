//  TripSummaryBuilderTests.swift
//  TripKitTests
//
//  Spec §9 / P8: tier counts, highlights (biggest / smallest / highest), auto title.

import Foundation
import Testing
import GeoData
import LocationEngine
@testable import TripKit

struct TripSummaryBuilderTests {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func adminEvent(_ tier: Int, _ id: Int, at offset: TimeInterval) -> PlaceEvent {
        PlaceEvent(
            place: PlaceRef(kind: .administrative, tier: Tier(rawValue: tier), id: id),
            enteredAt: t0.addingTimeInterval(offset),
            coordinate: Coordinate(latitude: 39, longitude: 32)
        )
    }

    private func place(_ id: Int, name: String, population: Int? = nil, elevation: Int? = nil) -> Place {
        Place(
            ref: PlaceRef(kind: .administrative, tier: .second, id: id),
            nameLocal: name, nameLocalized: nil, tierLabel: "", parentName: nil,
            population: population, populationYear: nil, areaKm2: nil,
            elevationMeters: elevation, article: nil,
            centroid: Coordinate(latitude: 39, longitude: 32)
        )
    }

    @Test func `Counts distinct places per tier`() {
        let trip = Trip(
            startedAt: t0,
            events: [
                adminEvent(1, 1, at: 0), adminEvent(2, 10, at: 60),
                adminEvent(2, 11, at: 120), adminEvent(2, 10, at: 900),   // revisit
                adminEvent(1, 2, at: 1_000),
            ],
            distanceMeters: 100_000
        )
        let summary = TripSummary.make(from: trip) { _ in nil }
        #expect(summary.countsByTier[Tier(rawValue: 1)] == 2)
        #expect(summary.countsByTier[Tier(rawValue: 2)] == 2)   // 10 counted once
    }

    @Test func `Highlights pick biggest, smallest and highest`() {
        let byID: [Int: Place] = [
            10: place(10, name: "Big", population: 500_000, elevation: 100),
            11: place(11, name: "Small", population: 900, elevation: 1_600),
            12: place(12, name: "Mid", population: 40_000, elevation: 800),
        ]
        let trip = Trip(
            startedAt: t0,
            events: [adminEvent(2, 10, at: 0), adminEvent(2, 11, at: 60), adminEvent(2, 12, at: 120)],
            distanceMeters: 1
        )
        let summary = TripSummary.make(from: trip) { byID[$0.id] }
        let names = summary.highlights.map(\.nameLocal)
        #expect(names.contains("Big"))
        #expect(names.contains("Small"))
        #expect(names.contains("Small"))          // also the highest (1_600 m)
        #expect(summary.highlights.count <= 3)
        // no duplicates
        #expect(Set(summary.highlights.map(\.ref)).count == summary.highlights.count)
    }

    @Test func `Highlights are empty when nothing resolves`() {
        let trip = Trip(startedAt: t0, events: [adminEvent(2, 10, at: 0)], distanceMeters: 1)
        #expect(TripSummary.make(from: trip) { _ in nil }.highlights.isEmpty)
    }

    @Test func `Auto title is first tier-1 to last tier-1`() {
        let events = [
            adminEvent(1, 34, at: 0), adminEvent(2, 340, at: 60),
            adminEvent(1, 41, at: 600), adminEvent(1, 52, at: 1_200),
        ]
        let names: [Int: String] = [34: "İstanbul", 41: "Kocaeli", 52: "Ordu", 340: "Kadıköy"]
        #expect(Trip.autoTitle(from: events) { names[$0.id] } == "İstanbul → Ordu")
    }

    @Test func `Auto title with a single province is just its name`() {
        let events = [adminEvent(1, 34, at: 0)]
        #expect(Trip.autoTitle(from: events) { _ in "İstanbul" } == "İstanbul")
    }

    @Test func `Auto title is nil before any province is known`() {
        let events = [adminEvent(2, 340, at: 0)]
        #expect(Trip.autoTitle(from: events) { _ in nil } == nil)
    }

    @Test func `Trip duration`() {
        let trip = Trip(startedAt: t0, endedAt: t0.addingTimeInterval(3_600))
        #expect(trip.duration == 3_600)
    }

    @Test func `notificationThread matches the Presence contract`() {
        let id = UUID()
        let trip = Trip(id: id, startedAt: t0)
        #expect(trip.notificationThread == "trip-\(id.uuidString)")
    }
}

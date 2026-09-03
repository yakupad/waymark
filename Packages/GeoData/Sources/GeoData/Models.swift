//  Models.swift
//  GeoData
//
//  Value types shared across the geo layer (spec Section 9). These are UIKit/SwiftUI
//  free and carry no CoreLocation dependency so the package stays unit-testable in
//  isolation (spec 6.1).

import Foundation

/// A WGS84 geographic coordinate. Plain data — no CoreLocation (spec 6.1).
public struct Coordinate: Hashable, Sendable, Codable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// What kind of place a reference points at. Administrative units differ by `tier`
/// (spec K6), not by a hard-coded province/district split.
public enum PlaceKind: Int, Sendable, Hashable, Codable {
    case administrative
    case settlement
}

/// Administrative depth. `1` is a province in Turkey, `2` a district — but the label is
/// data, never baked into code (spec K6). Modelled as a wrapper so a third tier in a
/// future country needs no type change.
public struct Tier: RawRepresentable, Hashable, Sendable, Comparable, Codable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public init(from decoder: any Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(Int.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static let first = Tier(rawValue: 1)
    public static let second = Tier(rawValue: 2)

    public static func < (lhs: Tier, rhs: Tier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// A lightweight, stable handle to a row in the pack. `tier` is `nil` for settlements.
public struct PlaceRef: Hashable, Sendable, Codable {
    public let kind: PlaceKind
    public let tier: Tier?
    public let id: Int

    public init(kind: PlaceKind, tier: Tier?, id: Int) {
        self.kind = kind
        self.tier = tier
        self.id = id
    }
}

/// User-facing tier label pair, straight from the `tier_label` table (spec K6).
public struct TierLabel: Hashable, Sendable {
    public let tier: Tier
    public let osmAdminLevel: Int?
    public let labelLocal: String
    public let labelEnglish: String

    public init(tier: Tier, osmAdminLevel: Int?, labelLocal: String, labelEnglish: String) {
        self.tier = tier
        self.osmAdminLevel = osmAdminLevel
        self.labelLocal = labelLocal
        self.labelEnglish = labelEnglish
    }
}

/// History summary text with the language-fallback chain already applied (spec 11.5).
public struct Article: Hashable, Sendable {
    public let summary: String
    public let language: String
    public let sourceURL: URL

    public init(summary: String, language: String, sourceURL: URL) {
        self.summary = summary
        self.language = language
        self.sourceURL = sourceURL
    }
}

/// A settlement point (village / town / hamlet / suburb — spec K4, schema 5.3).
public struct Settlement: Hashable, Sendable, Identifiable {
    public enum Kind: Int, Sendable, Hashable {
        case village = 0
        case town = 1
        case hamlet = 2
        case suburb = 3
    }

    public let id: Int
    public let parentID: Int
    public let nameLocal: String
    public let nameEnglish: String?
    public let kind: Kind
    public let coordinate: Coordinate
    public let population: Int?
    public let elevationMeters: Int?
    public let wikidataID: String?

    public init(
        id: Int,
        parentID: Int,
        nameLocal: String,
        nameEnglish: String?,
        kind: Kind,
        coordinate: Coordinate,
        population: Int?,
        elevationMeters: Int?,
        wikidataID: String?
    ) {
        self.id = id
        self.parentID = parentID
        self.nameLocal = nameLocal
        self.nameEnglish = nameEnglish
        self.kind = kind
        self.coordinate = coordinate
        self.population = population
        self.elevationMeters = elevationMeters
        self.wikidataID = wikidataID
    }
}

/// A fully hydrated place for the detail screen (spec Section 9). The name is always
/// shown in its local form; `nameLocalized` is the user-language name if present.
public struct Place: Identifiable, Sendable {
    public let ref: PlaceRef
    public let nameLocal: String
    public let nameLocalized: String?
    public let tierLabel: String
    public let parentName: String?
    public let population: Int?
    public let populationYear: Int?
    public let areaKm2: Double?
    public let elevationMeters: Int?
    public let article: Article?
    public let centroid: Coordinate

    public var id: PlaceRef { ref }

    public init(
        ref: PlaceRef,
        nameLocal: String,
        nameLocalized: String?,
        tierLabel: String,
        parentName: String?,
        population: Int?,
        populationYear: Int?,
        areaKm2: Double?,
        elevationMeters: Int?,
        article: Article?,
        centroid: Coordinate
    ) {
        self.ref = ref
        self.nameLocal = nameLocal
        self.nameLocalized = nameLocalized
        self.tierLabel = tierLabel
        self.parentName = parentName
        self.population = population
        self.populationYear = populationYear
        self.areaKm2 = areaKm2
        self.elevationMeters = elevationMeters
        self.article = article
        self.centroid = centroid
    }
}

/// Result of resolving one coordinate: the matched administrative unit per tier plus
/// the nearest settlement, if any (spec Section 9, algorithm 7.6).
public struct PlaceResolution: Sendable {
    /// tier -> matched unit. In v1 keys `1` and `2` fill in when the point is on land.
    public let administrative: [Tier: PlaceRef]
    public let settlement: PlaceRef?
    public let settlementDistanceMeters: Double?

    public init(
        administrative: [Tier: PlaceRef],
        settlement: PlaceRef?,
        settlementDistanceMeters: Double?
    ) {
        self.administrative = administrative
        self.settlement = settlement
        self.settlementDistanceMeters = settlementDistanceMeters
    }

    public static let empty = PlaceResolution(
        administrative: [:], settlement: nil, settlementDistanceMeters: nil
    )
}

// MARK: - Seams (spec 6.3)

/// The resolution seam consumed by `LocationEngine` (spec 6.3). Kept minimal and
/// exactly as specified so the state machine can be tested against a fake.
public protocol GeoResolving: Sendable {
    func resolve(coordinate: Coordinate) throws -> PlaceResolution
    func nearestSettlement(to coordinate: Coordinate, within meters: Double) throws -> Settlement?
}

/// Detail lookups for the UI layer (spec Section 10 "Yer detayı"). Separate from
/// `GeoResolving` because the hot path (the state machine) never needs it.
public protocol PlaceRepository: Sendable {
    /// tier labels for the (single, in v1) region, ordered by tier.
    func tierLabels() throws -> [TierLabel]
    /// Hydrate a reference. `language` drives the article fallback chain
    /// (`language -> en -> nil`, spec 11.5 / İ4).
    func place(for ref: PlaceRef, language: String) throws -> Place?
}

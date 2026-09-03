//  Surfaces.swift
//  Presence
//
//  The two output surfaces the coordinator drives (spec 8), behind protocols so tests
//  substitute fakes and the package stays free of ActivityKit on non-iOS.

import Foundation
import GeoData
import LocationEngine

/// Rendered Live Activity content (spec 8.2). `Codable` so it can serve directly as an
/// ActivityKit `ContentState`. Tier counts are keyed by tier *raw value* for Codable.
public struct LiveActivityState: Sendable, Equatable, Hashable, Codable {
    /// Current settlement or district name — the big line.
    public var headline: String
    /// "Merzifon, Amasya" — the hierarchy line.
    public var hierarchy: String
    public var population: Int?
    /// tier raw value → distinct places entered this trip.
    public var tierCounts: [Int: Int]
    public var settlementCount: Int
    public var updatedAt: Date

    public init(
        headline: String = "",
        hierarchy: String = "",
        population: Int? = nil,
        tierCounts: [Int: Int] = [:],
        settlementCount: Int = 0,
        updatedAt: Date = .distantPast
    ) {
        self.headline = headline
        self.hierarchy = hierarchy
        self.population = population
        self.tierCounts = tierCounts
        self.settlementCount = settlementCount
        self.updatedAt = updatedAt
    }
}

public struct PlaceNotification: Sendable, Equatable {
    public var title: String
    public var body: String
    /// `trip-{tripID}` — groups a trip's notifications (spec 8.3).
    public var threadIdentifier: String
    public var targetPlace: PlaceRef
    public var deepLink: URL?

    public init(
        title: String, body: String, threadIdentifier: String,
        targetPlace: PlaceRef, deepLink: URL? = nil
    ) {
        self.title = title
        self.body = body
        self.threadIdentifier = threadIdentifier
        self.targetPlace = targetPlace
        self.deepLink = deepLink
    }
}

public protocol ActivitySurface: Sendable {
    func start(_ state: LiveActivityState, thread: String) async
    func update(_ state: LiveActivityState) async
    func end(_ state: LiveActivityState) async
}

public protocol NotificationSurface: Sendable {
    @discardableResult
    func requestAuthorization() async -> Bool
    func post(_ notification: PlaceNotification) async
}

/// Deep link into a place detail screen (spec 8.3: tapping a notification).
public enum DeepLink {
    public static let scheme = "waymark"

    public static func url(for ref: PlaceRef) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "place"
        components.queryItems = [
            URLQueryItem(name: "kind", value: ref.kind == .settlement ? "settlement" : "administrative"),
            URLQueryItem(name: "id", value: String(ref.id)),
        ]
        if let tier = ref.tier {
            components.queryItems?.append(URLQueryItem(name: "tier", value: String(tier.rawValue)))
        }
        return components.url
    }

    public static func placeRef(from url: URL) -> PlaceRef? {
        guard url.scheme == scheme, url.host == "place",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let idString = items.first(where: { $0.name == "id" })?.value,
              let id = Int(idString)
        else { return nil }
        let kind: PlaceKind = items.first(where: { $0.name == "kind" })?.value == "settlement"
            ? .settlement : .administrative
        let tier = items.first(where: { $0.name == "tier" })?.value
            .flatMap(Int.init).map(Tier.init(rawValue:))
        return PlaceRef(kind: kind, tier: kind == .settlement ? nil : tier, id: id)
    }
}

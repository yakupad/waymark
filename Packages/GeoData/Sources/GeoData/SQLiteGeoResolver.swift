//  SQLiteGeoResolver.swift
//  GeoData
//
//  The spatial resolver (spec 7.6, prompt P3). Reads a region pack (`*.pack`, schema
//  5.3) with GRDB and answers "what place is this coordinate in?".
//
//  Algorithm (spec 7.6):
//    1. R*Tree bbox pre-filter for tier-1 candidates (usually 1–3)
//    2. read each candidate's geometry blob (LRU cache, capacity 8), ray-cast
//    3. for the matched tier-1, repeat over its tier-2 children — and so on: the number
//       of tiers comes from `tier_label`, never hard-coded (spec K6). A 3-tier country
//       just makes the loop run once more.
//    4. nearest settlement via `settlement_rtree` + haversine
//
//  Why GRDB (spec 17.3): mature R*Tree support, `Sendable`/concurrency friendly, a
//  single clean SPM dependency. `DatabaseQueue` serialises access, so the resolver is
//  safe to share across threads; the hot path is one serialised read per call, well
//  inside the < 5 ms budget (spec 7.6).

import Foundation
import GRDB

public final class SQLiteGeoResolver: GeoResolving, PlaceRepository, Sendable {

    public enum ResolverError: Error, Sendable {
        case emptyPack(String)
    }

    private let dbQueue: DatabaseQueue
    private let geometryCache: GeometryCache
    /// Tiers present in this pack, ascending (spec K6 — count is data, not code).
    private let tiers: [Tier]
    private let regionID: Int64
    /// bbox half-size used when `resolve` looks for a nearby settlement. This is only a
    /// query window — product thresholds (spec 7.5 `settlementRadius`) are applied by the
    /// caller against `PlaceResolution.settlementDistanceMeters`.
    private let settlementSearchRadiusMeters: Double

    // MARK: - Init

    public init(
        path: String,
        geometryCacheCapacity: Int = 8,
        settlementSearchRadiusMeters: Double = 5_000
    ) throws {
        var config = Configuration()
        config.readonly = true
        self.dbQueue = try DatabaseQueue(path: path, configuration: config)
        self.geometryCache = GeometryCache(capacity: geometryCacheCapacity)
        self.settlementSearchRadiusMeters = settlementSearchRadiusMeters

        let (regionID, tiers): (Int64, [Tier]) = try dbQueue.read { db in
            guard let regionID = try Int64.fetchOne(db, sql: "SELECT id FROM region ORDER BY id LIMIT 1") else {
                throw ResolverError.emptyPack("region table is empty")
            }
            let tierValues = try Int.fetchAll(
                db,
                sql: "SELECT tier FROM tier_label WHERE region_id = ? ORDER BY tier",
                arguments: [regionID]
            )
            guard !tierValues.isEmpty else {
                throw ResolverError.emptyPack("tier_label has no rows for region \(regionID)")
            }
            return (regionID, tierValues.map { Tier(rawValue: $0) })
        }
        self.regionID = regionID
        self.tiers = tiers
    }

    // MARK: - GeoResolving

    public func resolve(coordinate: Coordinate) throws -> PlaceResolution {
        try dbQueue.read { db in
            var administrative: [Tier: PlaceRef] = [:]
            var parentID: Int64?

            for tier in tiers {
                let candidateIDs = try candidateAdminIDs(
                    db, tier: tier, coordinate: coordinate, parentID: parentID
                )
                guard let hitID = try firstAdminContaining(db, coordinate: coordinate, ids: candidateIDs) else {
                    break   // outside every unit at this tier -> deeper tiers can't match
                }
                administrative[tier] = PlaceRef(kind: .administrative, tier: tier, id: Int(hitID))
                parentID = hitID
            }

            let nearest = try nearestSettlementRow(
                db, to: coordinate, within: settlementSearchRadiusMeters
            )
            return PlaceResolution(
                administrative: administrative,
                settlement: nearest.map { PlaceRef(kind: .settlement, tier: nil, id: $0.settlement.id) },
                settlementDistanceMeters: nearest?.distanceMeters
            )
        }
    }

    public func nearestSettlement(to coordinate: Coordinate, within meters: Double) throws -> Settlement? {
        try dbQueue.read { db in
            try nearestSettlementRow(db, to: coordinate, within: meters)?.settlement
        }
    }

    // MARK: - PlaceRepository

    public func tierLabels() throws -> [TierLabel] {
        try dbQueue.read { db in
            try TierLabel.fetchAll(db, regionID: regionID)
        }
    }

    public func place(for ref: PlaceRef, language: String) throws -> Place? {
        guard ref.kind == .administrative, let tier = ref.tier else {
            return try settlementPlace(for: ref, language: language)
        }
        return try dbQueue.read { db in
            guard let row = try Row.fetchOne(
                db, sql: "SELECT * FROM admin_unit WHERE id = ?", arguments: [ref.id]
            ) else { return nil }

            let labels = try TierLabel.fetchAll(db, regionID: regionID)
            let tierLabelText = label(for: tier, in: labels, language: language)

            var parentName: String?
            let parentID: Int64? = row["parent_id"]
            if let parentID {
                parentName = try String.fetchOne(
                    db, sql: "SELECT name_local FROM admin_unit WHERE id = ?", arguments: [parentID]
                )
            }

            let article = try fetchArticle(
                db, entityKind: 0, entityID: ref.id, language: language
            )

            let nameLocal: String = row["name_local"]
            let nameEnglish: String? = row["name_en"]
            let population: Int? = row["population"]
            let populationYear: Int? = row["population_year"]
            let areaKm2: Double? = row["area_km2"]
            let centroidLat: Double = row["centroid_lat"]
            let centroidLon: Double = row["centroid_lon"]
            return Place(
                ref: ref,
                nameLocal: nameLocal,
                nameLocalized: isEnglish(language) ? nameEnglish : nil,
                tierLabel: tierLabelText,
                parentName: parentName,
                population: population,
                populationYear: populationYear,
                areaKm2: areaKm2,
                elevationMeters: nil,
                article: article,
                centroid: Coordinate(latitude: centroidLat, longitude: centroidLon)
            )
        }
    }

    private func settlementPlace(for ref: PlaceRef, language: String) throws -> Place? {
        guard ref.kind == .settlement else { return nil }
        return try dbQueue.read { db in
            guard let row = try Row.fetchOne(
                db, sql: "SELECT * FROM settlement WHERE id = ?", arguments: [ref.id]
            ) else { return nil }

            let parentID: Int64 = row["parent_id"]
            let parentName = try String.fetchOne(
                db, sql: "SELECT name_local FROM admin_unit WHERE id = ?", arguments: [parentID]
            )
            let kindRaw: Int = row["kind"]
            let kindLabel: String
            switch Settlement.Kind(rawValue: kindRaw) ?? .village {
            case .village: kindLabel = isEnglish(language) ? "Village" : "Köy"
            case .town: kindLabel = isEnglish(language) ? "Town" : "Kasaba"
            case .hamlet: kindLabel = isEnglish(language) ? "Hamlet" : "Mezra"
            case .suburb: kindLabel = isEnglish(language) ? "Neighbourhood" : "Mahalle"
            }
            let article = try fetchArticle(db, entityKind: 1, entityID: ref.id, language: language)

            let nameLocal: String = row["name_local"]
            let nameEnglish: String? = row["name_en"]
            let population: Int? = row["population"]
            let elevation: Int? = row["elevation_m"]
            let lat: Double = row["lat"]
            let lon: Double = row["lon"]
            return Place(
                ref: ref,
                nameLocal: nameLocal,
                nameLocalized: isEnglish(language) ? nameEnglish : nil,
                tierLabel: kindLabel,
                parentName: parentName,
                population: population,
                populationYear: nil,
                areaKm2: nil,
                elevationMeters: elevation,
                article: article,
                centroid: Coordinate(latitude: lat, longitude: lon)
            )
        }
    }

    // MARK: - Candidate lookup

    private func candidateAdminIDs(
        _ db: Database, tier: Tier, coordinate: Coordinate, parentID: Int64?
    ) throws -> [Int64] {
        if let parentID {
            // Children of the matched parent — a small set, no bbox needed.
            return try Int64.fetchAll(
                db,
                sql: "SELECT id FROM admin_unit WHERE parent_id = ? AND tier = ? ORDER BY id",
                arguments: [parentID, tier.rawValue]
            )
        }
        // Top tier: R*Tree bbox pre-filter (spec 7.6 step 1).
        return try Int64.fetchAll(
            db,
            sql: """
                SELECT a.id
                FROM admin_rtree r
                JOIN admin_unit a ON a.id = r.id
                WHERE r.max_lon >= :lon AND r.min_lon <= :lon
                  AND r.max_lat >= :lat AND r.min_lat <= :lat
                  AND a.tier = :tier AND a.region_id = :region
                ORDER BY a.id
                """,
            arguments: [
                "lon": coordinate.longitude,
                "lat": coordinate.latitude,
                "tier": tier.rawValue,
                "region": regionID,
            ]
        )
    }

    private func firstAdminContaining(
        _ db: Database, coordinate: Coordinate, ids: [Int64]
    ) throws -> Int64? {
        for id in ids {
            let rings = try geometryCache.rings(for: Int(id)) { entityID in
                guard let blob = try Data.fetchOne(
                    db,
                    sql: "SELECT blob FROM geometry WHERE entity_id = ?",
                    arguments: [entityID]
                ) else { return [] }
                return try PolygonDecoder.decode(blob)
            }
            if PointInPolygon.contains(coordinate, rings: rings) {
                return id
            }
        }
        return nil
    }

    // MARK: - Settlements

    private struct SettlementHit {
        let settlement: Settlement
        let distanceMeters: Double
    }

    private func nearestSettlementRow(
        _ db: Database, to coordinate: Coordinate, within meters: Double
    ) throws -> SettlementHit? {
        let latHalf = Haversine.latitudeDegrees(forMeters: meters)
        let lonHalf = Haversine.longitudeDegrees(forMeters: meters, atLatitude: coordinate.latitude)

        let rows = try Row.fetchAll(
            db,
            sql: """
                SELECT s.*
                FROM settlement_rtree r
                JOIN settlement s ON s.id = r.id
                WHERE r.min_lon >= :west AND r.max_lon <= :east
                  AND r.min_lat >= :south AND r.max_lat <= :north
                """,
            arguments: [
                "west": coordinate.longitude - lonHalf,
                "east": coordinate.longitude + lonHalf,
                "south": coordinate.latitude - latHalf,
                "north": coordinate.latitude + latHalf,
            ]
        )

        var best: SettlementHit?
        for row in rows {
            let settlement = Settlement(row: row)
            let d = Haversine.distance(coordinate, settlement.coordinate)
            if d <= meters, d < (best?.distanceMeters ?? .infinity) {
                best = SettlementHit(settlement: settlement, distanceMeters: d)
            }
        }
        return best
    }

    // MARK: - Articles / labels

    private func fetchArticle(
        _ db: Database, entityKind: Int, entityID: Int, language: String
    ) throws -> Article? {
        let chain = languageFallbackChain(language)
        let placeholders = chain.map { _ in "?" }.joined(separator: ",")
        var args: [any DatabaseValueConvertible] = [entityKind, entityID]
        args.append(contentsOf: chain)

        let rows = try Row.fetchAll(
            db,
            sql: """
                SELECT lang, summary, source_url
                FROM article
                WHERE entity_kind = ? AND entity_id = ? AND lang IN (\(placeholders))
                """,
            arguments: StatementArguments(args)
        )

        var byLang: [String: Row] = [:]
        for row in rows {
            let lang: String = row["lang"]
            byLang[lang] = row
        }
        for lang in chain {
            guard let row = byLang[lang] else { continue }
            let summary: String = row["summary"]
            let urlString: String = row["source_url"]
            guard let url = URL(string: urlString) else { continue }
            return Article(summary: summary, language: lang, sourceURL: url)
        }
        return nil   // spec İ4: no article -> caller hides the card
    }

    /// `language -> en -> stop` (spec 11.5), de-duplicated, order preserved.
    private func languageFallbackChain(_ language: String) -> [String] {
        var chain = [language]
        if !isEnglish(language) { chain.append("en") }
        return chain
    }

    private func label(for tier: Tier, in labels: [TierLabel], language: String) -> String {
        guard let match = labels.first(where: { $0.tier == tier }) else { return "" }
        return isEnglish(language) ? match.labelEnglish : match.labelLocal
    }

    private func isEnglish(_ language: String) -> Bool {
        language.lowercased().hasPrefix("en")
    }
}

// MARK: - Row decoding

private extension Settlement {
    init(row: Row) {
        let id: Int = row["id"]
        let parentID: Int = row["parent_id"]
        let nameLocal: String = row["name_local"]
        let nameEnglish: String? = row["name_en"]
        let kindRaw: Int = row["kind"]
        let lat: Double = row["lat"]
        let lon: Double = row["lon"]
        let population: Int? = row["population"]
        let elevationMeters: Int? = row["elevation_m"]
        let wikidataID: String? = row["wikidata_id"]
        self.init(
            id: id,
            parentID: parentID,
            nameLocal: nameLocal,
            nameEnglish: nameEnglish,
            kind: Settlement.Kind(rawValue: kindRaw) ?? .village,
            coordinate: Coordinate(latitude: lat, longitude: lon),
            population: population,
            elevationMeters: elevationMeters,
            wikidataID: wikidataID
        )
    }
}

private extension TierLabel {
    static func fetchAll(_ db: Database, regionID: Int64) throws -> [TierLabel] {
        try Row.fetchAll(
            db,
            sql: """
                SELECT tier, osm_admin_level, label_local, label_en
                FROM tier_label WHERE region_id = ? ORDER BY tier
                """,
            arguments: [regionID]
        ).map { row in
            let tier: Int = row["tier"]
            let osmAdminLevel: Int? = row["osm_admin_level"]
            let labelLocal: String = row["label_local"]
            let labelEnglish: String = row["label_en"]
            return TierLabel(
                tier: Tier(rawValue: tier),
                osmAdminLevel: osmAdminLevel,
                labelLocal: labelLocal,
                labelEnglish: labelEnglish
            )
        }
    }
}

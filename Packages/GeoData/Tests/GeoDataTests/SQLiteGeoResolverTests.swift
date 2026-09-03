//  SQLiteGeoResolverTests.swift
//  GeoDataTests
//
//  Exercises the resolver against the synthetic pack from `build_pack.py --fixture`
//  (2 tier-1 units, 3 tier-2 units — one an enclave — and 5 settlements).

import Foundation
import Testing
@testable import GeoData

struct SQLiteGeoResolverTests {

    let resolver: SQLiteGeoResolver

    init() throws {
        let url = try #require(
            Bundle.module.url(forResource: "tr", withExtension: "pack"),
            "fixture tr.pack missing from the test bundle"
        )
        resolver = try SQLiteGeoResolver(path: url.path)
    }

    // MARK: - resolve

    @Test func `Resolves a point to its tier-1 and tier-2 unit`() throws {
        // Inside İlçe C1 (id 3), which is inside Test İli A (id 1), clear of the enclave.
        let res = try resolver.resolve(coordinate: Coordinate(latitude: 39.5, longitude: 31.7))
        #expect(res.administrative[.first]?.id == 1)
        #expect(res.administrative[.second]?.id == 3)
        #expect(res.administrative[.second]?.kind == .administrative)
    }

    @Test func `Enclave: a point in C1's hole resolves to C2, not C1`() throws {
        // (39.2, 31.7) is the shared centre — inside C1's outer ring but in its hole,
        // and inside the C2 enclave (id 4).
        let res = try resolver.resolve(coordinate: Coordinate(latitude: 39.2, longitude: 31.7))
        #expect(res.administrative[.first]?.id == 1)
        #expect(res.administrative[.second]?.id == 4)
    }

    @Test func `A point in the hole but outside the enclave has no tier-2 match`() throws {
        // Inside C1's hole (lat 39.31 ∈ [39.08, 39.32]) but above C2's top edge (39.3).
        let res = try resolver.resolve(coordinate: Coordinate(latitude: 39.315, longitude: 31.7))
        #expect(res.administrative[.first]?.id == 1)
        #expect(res.administrative[.second] == nil)
    }

    @Test func `A point outside every unit resolves to nothing`() throws {
        let res = try resolver.resolve(coordinate: Coordinate(latitude: 10, longitude: 10))
        #expect(res.administrative.isEmpty)
        #expect(res.settlement == nil)
    }

    @Test func `resolve attaches the nearest settlement with its distance`() throws {
        // Sitting almost on "Köy Bir" (id 1) at (39.05, 31.55).
        let res = try resolver.resolve(coordinate: Coordinate(latitude: 39.052, longitude: 31.551))
        #expect(res.settlement?.id == 1)
        let distance = try #require(res.settlementDistanceMeters)
        #expect(distance < 300)
    }

    // MARK: - nearestSettlement

    @Test func `nearestSettlement respects the radius`() throws {
        let far = try resolver.nearestSettlement(
            to: Coordinate(latitude: 39.052, longitude: 31.551), within: 10
        )
        #expect(far == nil)

        let near = try resolver.nearestSettlement(
            to: Coordinate(latitude: 39.052, longitude: 31.551), within: 2_000
        )
        #expect(near?.nameLocal == "Köy Bir")
        #expect(near?.kind == .village)
    }

    // MARK: - PlaceRepository

    @Test func `tierLabels comes from the pack, not from code`() throws {
        let labels = try resolver.tierLabels()
        #expect(labels.map(\.tier) == [.first, .second])
        #expect(labels[0].labelLocal == "İl")
        #expect(labels[0].labelEnglish == "Province")
        #expect(labels[1].labelLocal == "İlçe")
    }

    @Test func `place hydrates a unit with its Turkish label and article`() throws {
        let place = try #require(
            try resolver.place(for: PlaceRef(kind: .administrative, tier: .second, id: 3), language: "tr")
        )
        #expect(place.nameLocal == "İlçe C1")
        #expect(place.tierLabel == "İlçe")
        #expect(place.parentName == "Test İli A")
        #expect(place.article?.language == "tr")
        #expect(place.article?.summary.contains("enklav") == true)
        #expect(place.article?.sourceURL.absoluteString.hasPrefix("https://tr.wikipedia.org") == true)
    }

    @Test func `place uses the English label and article when the UI language is English`() throws {
        let place = try #require(
            try resolver.place(for: PlaceRef(kind: .administrative, tier: .second, id: 3), language: "en")
        )
        #expect(place.tierLabel == "District")
        #expect(place.nameLocalized == nil)   // fixture has no name_en for C1
        #expect(place.article?.language == "en")
    }

    @Test func `place falls back to English when the requested language is missing`() throws {
        // İlçe D1 (id 5) has only a 'tr' article; requesting 'fr' should fall to… nothing,
        // because the chain is fr -> en and there is no 'en' row either (spec İ4).
        let place = try #require(
            try resolver.place(for: PlaceRef(kind: .administrative, tier: .second, id: 5), language: "fr")
        )
        #expect(place.article == nil)
    }

    @Test func `place falls back from a missing language to the English article`() throws {
        // İlçe C1 (id 3) has both 'tr' and 'en'. Asking for 'de' -> chain de, en -> 'en'.
        let place = try #require(
            try resolver.place(for: PlaceRef(kind: .administrative, tier: .second, id: 3), language: "de")
        )
        #expect(place.article?.language == "en")
    }

    @Test func `Resolver is shareable across concurrent tasks`() async throws {
        let resolver = self.resolver
        await withTaskGroup(of: Int?.self) { group in
            for _ in 0..<16 {
                group.addTask {
                    try? resolver.resolve(
                        coordinate: Coordinate(latitude: 39.5, longitude: 31.7)
                    ).administrative[.second]?.id
                }
            }
            for await id in group {
                #expect(id == 3)
            }
        }
    }
}

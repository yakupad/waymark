//  NotificationCopyTests.swift
//  PresenceTests
//
//  Spec 8.3 copy + the Turkish locative suffix (spec R6 — İ/ı, vowel harmony).

import Foundation
import Testing
import GeoData
import LocationEngine
@testable import Presence

struct NotificationCopyTests {

    @Test(arguments: [
        ("Merzifon", "Merzifon'dasın"),   // back unrounded, voiced end
        ("Amasya", "Amasya'dasın"),       // ends in vowel
        ("İzmir", "İzmir'desin"),          // front unrounded
        ("Sinop", "Sinop'tasın"),          // back, voiceless end -> -ta
        ("Bolu", "Bolu'dasın"),            // ends in rounded vowel u -> loc -da (harmony a)
        ("Çorum", "Çorum'dasın"),
        ("Uşak", "Uşak'tasın"),            // voiceless k
        ("Niğde", "Niğde'desin"),
        ("Ordu", "Ordu'dasın"),
    ])
    func `Turkish locative phrase`(input: String, expected: String) {
        #expect(TurkishLocative.phrase(input) == expected)
    }

    @Test func `Turkish notification title and body`() {
        let ref = adminRef(2, 7)
        let place = makePlace(ref, name: "Merzifon", parent: "Amasya", population: 52_000)
        let n = DefaultNotificationCopy().makeNotification(
            for: place, ref: ref, thread: "trip-abc", language: "tr"
        )
        #expect(n.title == "Merzifon'dasın")
        #expect(n.body.hasPrefix("Amasya · "))
        #expect(n.body.contains("nüfus"))
        #expect(n.threadIdentifier == "trip-abc")
        #expect(n.deepLink?.scheme == "waymark")
    }

    @Test func `English notification copy`() {
        let ref = adminRef(1, 3)
        let place = makePlace(ref, name: "Amasya", parent: nil, population: 337_000)
        let n = DefaultNotificationCopy().makeNotification(
            for: place, ref: ref, thread: "trip-x", language: "en"
        )
        #expect(n.title == "You're in Amasya")
        #expect(n.body.contains("pop."))
    }

    @Test func `Body omits missing pieces gracefully`() {
        let ref = adminRef(1, 3)
        let place = makePlace(ref, name: "Nowhere")   // no parent, no population
        let n = DefaultNotificationCopy().makeNotification(
            for: place, ref: ref, thread: "t", language: "tr"
        )
        #expect(n.body.isEmpty)
    }
}

struct DeepLinkTests {

    @Test func `Round-trips an administrative ref`() throws {
        let ref = adminRef(2, 42)
        let url = try #require(DeepLink.url(for: ref))
        #expect(DeepLink.placeRef(from: url) == ref)
    }

    @Test func `Round-trips a settlement ref`() throws {
        let ref = settlementRef(99)
        let url = try #require(DeepLink.url(for: ref))
        #expect(DeepLink.placeRef(from: url) == ref)
    }

    @Test func `Rejects a foreign URL`() {
        #expect(DeepLink.placeRef(from: URL(string: "https://example.com/place?id=1")!) == nil)
    }
}

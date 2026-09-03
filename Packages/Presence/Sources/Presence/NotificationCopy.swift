//  NotificationCopy.swift
//  Presence
//
//  Builds the notification title/body (spec 8.3):
//
//      Title:  Merzifon'dasın            (tr)  /  You're in Merzifon        (en)
//      Body:   Amasya · 52.000 nüfus     (tr)  /  Amasya · pop. 52,000      (en)
//
//  Behind a protocol so F8's full localisation pass (xcstrings) can replace it. The
//  default handles Turkish locative suffixes with vowel harmony (spec R6).

import Foundation
import GeoData
import LocationEngine

public protocol NotificationCopy: Sendable {
    /// `location` is the pre-built hierarchy line ("Çumra, Konya 42") — the caller
    /// walks the chain and embeds the plate code.
    func makeNotification(
        for place: Place, ref: PlaceRef, location: String, thread: String, language: String
    ) -> PlaceNotification
}

public struct DefaultNotificationCopy: NotificationCopy {

    public init() {}

    public func makeNotification(
        for place: Place, ref: PlaceRef, location: String, thread: String, language: String
    ) -> PlaceNotification {
        let isTurkish = language.lowercased().hasPrefix("tr")
        let locale = Locale(identifier: isTurkish ? "tr_TR" : "en_US")

        let title: String
        if isTurkish {
            title = TurkishLocative.phrase(place.nameLocal)
        } else {
            title = "You're in \(place.nameLocalized ?? place.nameLocal)"
        }

        var bodyParts: [String] = []
        if !location.isEmpty {
            bodyParts.append(location)
        }
        if let population = place.population {
            let number = population.formatted(.number.locale(locale))
            bodyParts.append(isTurkish ? "\(number) nüfus" : "pop. \(number)")
        }

        return PlaceNotification(
            title: title,
            body: bodyParts.joined(separator: " · "),
            threadIdentifier: thread,
            targetPlace: ref,
            deepLink: DeepLink.url(for: ref)
        )
    }
}

/// Turkish locative ("-da/-de/-ta/-te") + 2nd-person present ("-sın/-sin/-sun/-sün"),
/// with vowel harmony and the voiceless-consonant rule. Proper nouns take an apostrophe
/// before the suffix: `Merzifon` → `Merzifon'dasın`.
enum TurkishLocative {

    static func phrase(_ properNoun: String) -> String {
        let trimmed = properNoun.trimmingCharacters(in: .whitespaces)
        guard let lastVowel = lastVowel(in: trimmed) else { return trimmed }
        let loc = locativeSuffix(lastVowel: lastVowel, endsVoiceless: endsVoiceless(trimmed))
        let person = secondPerson(afterVowel: loc.last!)
        return "\(trimmed)'\(loc)\(person)"
    }

    private static let backVowels: Set<Character> = ["a", "ı", "o", "u"]
    private static let frontVowels: Set<Character> = ["e", "i", "ö", "ü"]
    private static let voiceless: Set<Character> = ["f", "s", "t", "k", "ç", "ş", "h", "p"]

    private static func lastVowel(in word: String) -> Character? {
        let lowered = word.lowercased(with: Locale(identifier: "tr_TR"))
        return lowered.reversed().first { backVowels.contains($0) || frontVowels.contains($0) }
    }

    private static func endsVoiceless(_ word: String) -> Bool {
        guard let last = word.lowercased(with: Locale(identifier: "tr_TR")).last else { return false }
        return voiceless.contains(last)
    }

    private static func locativeSuffix(lastVowel: Character, endsVoiceless: Bool) -> String {
        let back = backVowels.contains(lastVowel)
        switch (back, endsVoiceless) {
        case (true, false): return "da"
        case (false, false): return "de"
        case (true, true): return "ta"
        case (false, true): return "te"
        }
    }

    private static func secondPerson(afterVowel vowel: Character) -> String {
        switch vowel {
        case "a", "ı": return "sın"
        case "e", "i": return "sin"
        case "o", "u": return "sun"
        case "ö", "ü": return "sün"
        default: return "sın"
        }
    }
}

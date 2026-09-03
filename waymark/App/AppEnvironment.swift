//  AppEnvironment.swift
//  waymark
//
//  Dependency-injection root (spec 6.4). Built once at launch and handed down the view
//  tree via the environment.

import Foundation
import SwiftUI
import GeoData
import LocationEngine
import TripKit
import Presence

@MainActor
final class AppEnvironment {

    let resolver: SQLiteGeoResolver
    let tripStore: TripStore
    let settings: SettingsStore
    let locationProvider: any LocationProviding
    let presence: PresenceCoordinator

    /// The UI language used for place names and articles (spec 11.5 fallback chain).
    let language: String

    init() throws {
        guard let packURL = Bundle.main.url(forResource: "tr", withExtension: "pack") else {
            throw StartupError.missingPack
        }
        resolver = try SQLiteGeoResolver(path: packURL.path)
        tripStore = try TripStore()
        settings = SettingsStore()
        language = Locale.current.language.languageCode?.identifier ?? "en"

        #if targetEnvironment(simulator)
        let provider = SimulatedLocationProvider()
        #else
        let provider = CoreLocationProvider()
        #endif
        locationProvider = provider

        presence = PresenceCoordinator(
            activity: LiveActivitySurface(),
            notifications: UserNotificationSurface(),
            places: resolver,
            policy: PresencePolicy(sensitivity: settings.sensitivity),
            gate: NotificationGate(config: settings.gateConfig),
            language: language
        )
    }

    enum StartupError: Error { case missingPack }
}

// MARK: - Environment plumbing

extension EnvironmentValues {
    @Entry var appEnvironment: AppEnvironment? = nil
}

extension View {
    func appEnvironment(_ value: AppEnvironment) -> some View {
        environment(\.appEnvironment, value)
    }
}

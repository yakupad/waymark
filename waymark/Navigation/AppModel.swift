//  AppModel.swift
//  waymark
//
//  Root coordinator (spec 6.4). SwiftUI-native: a selected tab plus one navigation path
//  per tab, and sheet/cover flags. Child screens push `AppRoute` values; the
//  `.navigationDestination` in `RootView` resolves them.

import Foundation
import SwiftUI
import AppIntents
import GeoData
import LocationEngine
import TripKit

enum AppTab: Hashable {
    case home, history, settings
}

enum AppRoute: Hashable {
    case place(PlaceRef)
    case tripSummary(UUID)
    case about
    case debug
}

@MainActor
@Observable
final class AppModel {

    var selectedTab: AppTab = .home
    var homePath: [AppRoute] = []
    var historyPath: [AppRoute] = []
    var settingsPath: [AppRoute] = []

    /// Push a route onto whichever tab is showing, so a detail opened from a
    /// modal (active trip, just-finished summary) or from any tab lands on the
    /// stack the user is actually looking at.
    func push(_ route: AppRoute) {
        switch selectedTab {
        case .home: homePath.append(route)
        case .history: historyPath.append(route)
        case .settings: settingsPath.append(route)
        }
    }

    let env: AppEnvironment

    /// Trip lifecycle + modal flags live in the process-wide `TripController` so an
    /// App Intent can start a trip without the app's UI. These read through to it.
    var liveTrip: LiveTripController { env.liveTrip }
    var permissions: PermissionsModel { env.permissions }

    init(env: AppEnvironment) {
        self.env = env
    }

    // MARK: - Trip flow

    func startTrip() {
        try? TripController.shared.start()
        // The system donates intents it runs; an in-app tap it doesn't — so feed
        // prediction here (spec §11: learn "starts a trip every morning").
        Task { try? await IntentDonationManager.shared.donate(intent: StartTripIntent()) }
    }

    func endTrip() {
        TripController.shared.end()
        Task { try? await IntentDonationManager.shared.donate(intent: EndTripIntent()) }
    }

    func dismissSummary() {
        TripController.shared.justFinished = nil
    }

    /// R4: a trip from a previous launch that never got an `endedAt` (killed in the
    /// background). We surface it so the user can keep it or discard it (spec §7.7 /
    /// R4), rather than silently finalising.
    var recoveredTrip: RecoveredTrip?

    struct RecoveredTrip: Identifiable {
        let id: UUID
        let title: String
        let placeCount: Int
        let distanceMeters: Double
    }

    func recoverUnfinishedTripIfNeeded() {
        guard let record = try? env.tripStore.unfinishedTrip() else { return }
        let events = record.events
        let title = record.title
            ?? Trip.autoTitle(from: events) { [env] ref in
                try? env.resolver.place(for: ref, language: env.language)?.nameLocal
            }
            ?? String(localized: "Recovered trip")
        recoveredTrip = RecoveredTrip(
            id: record.id, title: title,
            placeCount: Set(events.map(\.place)).count,
            distanceMeters: record.distanceMeters
        )
    }

    func keepRecoveredTrip() {
        guard let recoveredTrip, let record = try? env.tripStore.trip(id: recoveredTrip.id) else { return }
        let events = record.events
        let title = Trip.autoTitle(from: events) { [env] ref in
            try? env.resolver.place(for: ref, language: env.language)?.nameLocal
        }
        try? env.tripStore.finishTrip(
            record, at: record.startedAt, events: events, route: record.route,
            distanceMeters: record.distanceMeters, title: title
        )
        self.recoveredTrip = nil
    }

    func discardRecoveredTrip() {
        if let recoveredTrip, let record = try? env.tripStore.trip(id: recoveredTrip.id) {
            try? env.tripStore.delete(record)
        }
        recoveredTrip = nil
    }
}

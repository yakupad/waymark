//  AppModel.swift
//  waymark
//
//  Root coordinator (spec 6.4). SwiftUI-native: a selected tab plus one navigation path
//  per tab, and sheet/cover flags. Child screens push `AppRoute` values; the
//  `.navigationDestination` in `RootView` resolves them.

import Foundation
import SwiftUI
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

    /// The active-trip screen is a full-screen cover over Home.
    var activeTripPresented = false
    /// Set when a trip ends — drives the summary sheet.
    var justFinished: FinishedTrip?

    struct FinishedTrip: Identifiable {
        let id = UUID()
        let summary: TripSummary
        let tripID: UUID?
    }

    let env: AppEnvironment
    let liveTrip: LiveTripController
    let permissions: PermissionsModel

    init(env: AppEnvironment) {
        self.env = env
        let permissions = PermissionsModel(env: env)
        self.permissions = permissions
        self.liveTrip = LiveTripController(env: env, permissions: permissions)
    }

    // MARK: - Trip flow

    func startTrip() {
        liveTrip.start()
        activeTripPresented = true
    }

    func endTrip() {
        let summary = liveTrip.stop()
        justFinished = FinishedTrip(summary: summary, tripID: liveTrip.finishedTripID)
        activeTripPresented = false
    }

    func dismissSummary() {
        justFinished = nil
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

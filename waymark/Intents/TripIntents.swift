//  TripIntents.swift
//  waymark
//
//  App Intents so a trip can start / stop without opening the app — the user wires
//  them to a Shortcuts personal automation ("when my car's Bluetooth connects →
//  Start a Waymark trip", or a CarPlay / "when Maps opens" trigger). Spec §11.
//
//  Both run headless in the main app process (`.main`) because they touch the
//  in-memory `LiveTripController`.

import AppIntents
import TripKit

struct StartTripIntent: AppIntent {
    static let title: LocalizedStringResource = "Start a Trip"
    static let description = IntentDescription(
        "Begins tracking the provinces, districts and towns you pass. Safe to run from an automation — if a trip is already running it does nothing."
    )

    static var supportedModes: IntentModes { .background }
    static var allowedExecutionTargets: IntentExecutionTargets { .main }

    @Dependency private var trips: TripController

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let wasRunning = trips.isRunning
        try trips.start()
        return .result(dialog: wasRunning ? "A trip is already running." : "Trip started.")
    }
}

struct EndTripIntent: AppIntent {
    static let title: LocalizedStringResource = "End Trip"
    static let description = IntentDescription(
        "Ends the current trip and saves it. Does nothing if no trip is running."
    )

    static var supportedModes: IntentModes { .background }
    static var allowedExecutionTargets: IntentExecutionTargets { .main }

    @Dependency private var trips: TripController

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let finished = trips.end() else {
            return .result(dialog: "No trip is running.")
        }
        let places = finished.summary.countsByTier.values.reduce(0, +) + finished.summary.settlementCount
        return .result(dialog: "Trip saved — \(places) places, \(Format.distance(finished.summary.distanceMeters)).")
    }
}

struct WaymarkShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartTripIntent(),
            phrases: [
                "Start a trip in \(.applicationName)",
                "Start a \(.applicationName) trip",
            ],
            shortTitle: "Start a Trip",
            systemImageName: "location.north.line.fill"
        )
        AppShortcut(
            intent: EndTripIntent(),
            phrases: [
                "End my \(.applicationName) trip",
                "Stop the trip in \(.applicationName)",
            ],
            shortTitle: "End Trip",
            systemImageName: "flag.checkered"
        )
    }
}

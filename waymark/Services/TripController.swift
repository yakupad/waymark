//  TripController.swift
//  waymark
//
//  The one place trips start and stop — from the Home button, the screenshot hook,
//  or an App Intent fired by a Shortcuts automation (spec §11 "otomatik başlatma").
//  Owns the modal-presentation flags so a trip started headlessly still shows the
//  active-trip screen the next time the app is opened.

import Foundation
import SwiftUI
import TripKit

@MainActor
@Observable
final class TripController {

    static let shared = TripController()
    private init() {}

    /// Drives the full-screen cover in `RootView`. Set true when a trip starts
    /// (including from the background); cleared when it ends.
    var isActiveTripPresented = false
    /// Drives the summary sheet in `RootView`.
    var justFinished: FinishedTrip?

    struct FinishedTrip: Identifiable {
        let id = UUID()
        let summary: TripSummary
        let tripID: UUID?
    }

    enum Failure: Error, CustomLocalizedStringResourceConvertible {
        case notReady
        var localizedStringResource: LocalizedStringResource {
            "Waymark isn't ready. Open the app once, then try again."
        }
    }

    private var live: LiveTripController? { AppEnvironment.shared?.liveTrip }

    var isRunning: Bool { live?.isRunning ?? false }

    /// Idempotent — a second call while a trip is already running is a no-op, so a
    /// Shortcuts automation that fires twice can't start two trips.
    func start() throws {
        guard let live else { throw Failure.notReady }
        guard !live.isRunning else { return }
        live.start()
        isActiveTripPresented = true
    }

    @discardableResult
    func end() -> FinishedTrip? {
        guard let live, live.isRunning else { return nil }
        let summary = live.stop()
        let finished = FinishedTrip(summary: summary, tripID: live.finishedTripID)
        isActiveTripPresented = false
        justFinished = finished
        TravelNudge.shared.noteTripEnded()
        return finished
    }
}

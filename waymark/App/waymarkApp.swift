//
//  waymarkApp.swift
//  waymark
//

import SwiftUI

@main
struct waymarkApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
    }
}

/// Builds the DI root once, then hands off to `RootView`. If the pack can't load we show
/// a diagnostic rather than crashing.
struct AppRootView: View {
    @State private var state: LoadState = .loading

    enum LoadState {
        case loading
        case ready(AppModel)
        case failed(String)
    }

    var body: some View {
        switch state {
        case .loading:
            ProgressView().task { load() }
        case .ready(let model):
            RootView(model: model)
                .appEnvironment(model.env)
        case .failed(let message):
            ContentUnavailableView(
                "Couldn't start",
                systemImage: "exclamationmark.triangle",
                description: Text(verbatim: message)
            )
        }
    }

    @MainActor
    private func load() {
        do {
            let env = try AppEnvironment()
            let model = AppModel(env: env)
            model.recoverUnfinishedTripIfNeeded()
            state = .ready(model)
            applyLaunchScreenHook(model)
        } catch {
            state = .failed(String(describing: error))
        }
    }

    /// Screenshot / demo hook: `-waymarkScreen active|summary` jumps straight into a
    /// running demo trip (or a finished one) so App Store captures and reviewers
    /// don't have to drive. No effect without the argument.
    @MainActor
    private func applyLaunchScreenHook(_ model: AppModel) {
        guard let i = CommandLine.arguments.firstIndex(of: "-waymarkScreen"),
              i + 1 < CommandLine.arguments.count else { return }
        let screen = CommandLine.arguments[i + 1]
        model.startTrip()
        if screen == "summary" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 35) { model.endTrip() }
        } else if screen == "place" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 18) {
                model.activeTripPresented = false
                if let ref = model.liveTrip.passedPlaces.last?.ref {
                    model.homePath.append(.place(ref))
                }
            }
        }
    }
}

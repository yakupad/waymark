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
        } catch {
            state = .failed(String(describing: error))
        }
    }
}

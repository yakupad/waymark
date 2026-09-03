//  RootView.swift
//  waymark
//
//  The tab shell + per-tab navigation stacks. `AppRoute` destinations resolve here so
//  every tab can push a place detail or a trip summary (spec §10).

import SwiftUI

struct RootView: View {
    @Bindable var model: AppModel
    @State private var trips = TripController.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $model.selectedTab) {
            Tab("Home", systemImage: "location.circle", value: AppTab.home) {
                NavigationStack(path: $model.homePath) {
                    HomeView(model: model)
                        .withAppRoutes(model: model)
                }
            }
            Tab("History", systemImage: "clock.arrow.circlepath", value: AppTab.history) {
                NavigationStack(path: $model.historyPath) {
                    HistoryView(model: model)
                        .withAppRoutes(model: model)
                }
            }
            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                NavigationStack(path: $model.settingsPath) {
                    SettingsView(model: model)
                        .withAppRoutes(model: model)
                }
            }
        }
        .fullScreenCover(isPresented: $trips.isActiveTripPresented) {
            ActiveTripView(model: model)
        }
        .sheet(item: $trips.justFinished) { finished in
            NavigationStack {
                TripSummaryView(
                    source: .justFinished(summary: finished.summary, tripID: finished.tripID),
                    model: model
                )
            }
        }
        .task { TravelNudge.shared.setEnabled(model.env.settings.travelReminders) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { TravelNudge.shared.appBecameActive() }
        }
    }
}

private struct AppRoutesModifier: ViewModifier {
    let model: AppModel

    func body(content: Content) -> some View {
        content.navigationDestination(for: AppRoute.self) { route in
            switch route {
            case .place(let ref):
                PlaceDetailView(ref: ref, model: model)
            case .tripSummary(let id):
                TripSummaryView(source: .stored(id: id), model: model)
            case .about:
                AboutView()
            case .debug:
                #if DEBUG
                DebugMenuView(model: model)
                #else
                EmptyView()
                #endif
            }
        }
    }
}

extension View {
    func withAppRoutes(model: AppModel) -> some View {
        modifier(AppRoutesModifier(model: model))
    }
}

//  ActiveTripView.swift
//  waymark
//
//  Spec §10 "Aktif yolculuk": current place (big), live route line, passed places
//  (reverse chronological), "End".

import SwiftUI
import DesignSystem

struct ActiveTripView: View {
    let model: AppModel

    private var live: LiveTripController { model.liveTrip }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if model.permissions.showBackgroundUpgradeCard {
                    backgroundUpgradeCard
                }
                header
                RouteMap(route: live.route, follow: live.currentCoordinate)
                    .frame(height: 200)
                passedList
            }
            .navigationTitle("Active trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("End", role: .destructive) { model.endTrip() }
                }
            }
        }
    }

    private var backgroundUpgradeCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Keep going with the screen off", comment: "Background-location upgrade card title")
                .font(.headline)
            Text("Right now Waymark only sees your location while the app is open. Allow \u{201C}Always\u{201D} so it can still tell you when you enter a new place with your phone in your pocket. Your location never leaves your device.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button("Not now") { model.permissions.dismissBackgroundUpgrade() }
                    .buttonStyle(.bordered)
                Spacer()
                Button("Allow Always") { model.permissions.requestBackgroundUpgrade() }
                    .buttonStyle(.borderedProminent)
                    .tint(.brand)
            }
            .font(.subheadline)
        }
        .padding(Spacing.md)
        .background(.background.secondary, in: .rect(cornerRadius: Radius.md))
        .padding(Spacing.md)
    }

    @ViewBuilder
    private var header: some View {
        VStack(spacing: Spacing.xs) {
            if let confirmed = live.headline {
                Text(confirmed)
                    .font(.placeHeadline)
                    .multilineTextAlignment(.center)
                if let hierarchy = live.hierarchy {
                    Text(hierarchy).foregroundStyle(.secondary)
                }
            } else if let pending = live.pendingPlace {
                Text(pending)
                    .font(.placeHeadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Text("Confirming…", comment: "Shown under a place name that isn't confirmed yet")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                Text(live.fixCount == 0 ? String(localized: "Waiting for GPS…") : String(localized: "Locating…"))
                    .font(.placeTitle)
                    .foregroundStyle(.secondary)
            }
            Text(Format.distance(live.distanceMeters))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, Spacing.xs)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.lg)
    }

    @ViewBuilder
    private var passedList: some View {
        if live.passedPlaces.isEmpty {
            ContentUnavailableView(
                "No places yet", systemImage: "signpost.right.and.left",
                description: Text("Places you pass will appear here.")
            )
            .frame(maxHeight: .infinity)
        } else {
            List(live.passedPlaces) { passed in
                Button {
                    model.homePath.append(.place(passed.ref))
                    model.activeTripPresented = false
                } label: {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(passed.name).font(.headline)
                        HStack(spacing: Spacing.sm) {
                            Text(passed.tierLabel)
                            if let parent = passed.parentName {
                                Text(verbatim: "·")
                                Text(parent)
                            }
                            if let population = passed.population {
                                Text(verbatim: "·")
                                Text("\(Format.population(population)) pop.")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
    }
}

//  HomeView.swift
//  waymark
//
//  Spec §10 "Ana ekran": big "Start a trip" button, current-location card, recent trips.

import SwiftUI
import GeoData
import LocationEngine
import TripKit
import DesignSystem

@MainActor
@Observable
final class HomeModel {
    private(set) var recentTrips: [TripListItem] = []
    private(set) var currentPlace: Place?

    let env: AppEnvironment

    init(env: AppEnvironment) {
        self.env = env
    }

    func reload() {
        recentTrips = ((try? env.tripStore.allTrips()) ?? []).prefix(3).map(TripListItem.init)
    }

    /// One-shot: resolve wherever the last trip ended, as a stand-in for "current
    /// location" until a live trip is running. A real one-shot GPS fix is a refinement.
    func resolveLastKnown() {
        guard
            let lastEvent = ((try? env.tripStore.allTrips()) ?? []).first?.events.last
        else { return }
        currentPlace = try? env.resolver.place(for: lastEvent.place, language: env.language)
    }
}

struct HomeView: View {
    let model: AppModel
    @State private var home: HomeModel

    init(model: AppModel) {
        self.model = model
        _home = State(initialValue: HomeModel(env: model.env))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                PrimaryButton("Start a trip", systemImage: "car.fill") {
                    model.startTrip()
                }
                .padding(.top, Spacing.md)

                if let recovered = model.recoveredTrip {
                    recoveryCard(recovered)
                }

                if let place = home.currentPlace {
                    currentLocationCard(place)
                }

                recentSection
            }
            .padding(Spacing.md)
        }
        .navigationTitle("Waymark")
        .background(Color(.systemGroupedBackground))
        .scrollContentBackground(.hidden)
        .onAppear {
            home.reload()
            home.resolveLastKnown()
        }
    }

    private func recoveryCard(_ trip: AppModel.RecoveredTrip) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Unfinished trip", comment: "Recovery card title (spec R4)")
                    .font(.headline)
                Text("Waymark closed during \u{201C}\(trip.title)\u{201D} — \(trip.placeCount) places, \(Format.distance(trip.distanceMeters)).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Discard", role: .destructive) { model.discardRecoveredTrip() }
                        .buttonStyle(.bordered)
                    Spacer()
                    Button("Keep it") {
                        model.keepRecoveredTrip()
                        home.reload()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.brand)
                }
                .font(.subheadline)
            }
        }
    }

    private func currentLocationCard(_ place: Place) -> some View {
        Button {
            model.homePath.append(.place(place.ref))
        } label: {
            Card {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "location.north.fill")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(Color.signBlue)
                        Text("Near here", comment: "Header of the current-location card")
                            .font(.signLabel).signCaps()
                            .foregroundStyle(.secondary)
                        Spacer()
                        TierShield(place.tierLabel)
                    }
                    Text(place.nameLocal).font(.placeTitle)
                    if let parent = place.parentName {
                        Text(parent)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var recentSection: some View {
        if !home.recentTrips.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SignHeader("Recent trips")
                ForEach(home.recentTrips) { trip in
                    Button {
                        model.homePath.append(.tripSummary(trip.id))
                    } label: {
                        Card { TripRowView(item: trip) }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

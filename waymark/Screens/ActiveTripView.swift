//  ActiveTripView.swift
//  waymark
//
//  Spec §10 "Aktif yolculuk": current place (big), live route line, passed places
//  (reverse chronological), "End".

import SwiftUI
import DesignSystem

struct ActiveTripView: View {
    let model: AppModel

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var live: LiveTripController { model.liveTrip }
    /// Landscape on a phone — very short. Split into two columns instead of a
    /// stack that can't fit and can't scroll.
    private var isLandscapePhone: Bool {
        #if DEBUG
        if CommandLine.arguments.contains("-forceWideLayout") { return true }
        #endif
        return verticalSizeClass == .compact
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLandscapePhone { landscapeLayout } else { portraitLayout }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Active trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("End", role: .destructive) { model.endTrip() }
                }
            }
        }
    }

    private var portraitLayout: some View {
        VStack(spacing: Spacing.md) {
            if model.permissions.showBackgroundUpgradeCard {
                backgroundUpgradeCard
            }
            header.padding(.horizontal, Spacing.md)
            mapView.padding(.horizontal, Spacing.md)
            passedList
        }
        .padding(.top, Spacing.sm)
    }

    private var landscapeLayout: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: Spacing.md) {
                if model.permissions.showBackgroundUpgradeCard {
                    backgroundUpgradeCard
                }
                header
                routeMap   // no fixed height — fills the rest of the column
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity)

            Divider()

            passedList
                .frame(maxWidth: .infinity)
                .padding(.top, Spacing.sm)
        }
    }

    private var mapView: some View {
        routeMap.frame(height: 190)
    }

    private var routeMap: some View {
        RouteMap(route: live.route, follow: live.currentCoordinate)
            .frame(maxWidth: .infinity)
            .clipShape(.rect(cornerRadius: Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(.quaternary, lineWidth: 1))
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
        if let confirmed = live.headline {
            directionPanel(
                label: "You are in", name: confirmed,
                sub: live.hierarchy, tint: .signBlue
            )
        } else if let pending = live.pendingPlace {
            directionPanel(
                label: "Confirming", name: pending,
                sub: String(localized: "Settling in…"), tint: .signAmber
            )
        } else {
            directionPanel(
                label: live.fixCount == 0 ? "Waiting for GPS" : "Locating",
                name: live.fixCount == 0 ? "—" : String(localized: "Locating…"),
                sub: nil, tint: .signBlue
            )
        }
    }

    private func directionPanel(
        label: LocalizedStringKey, name: String, sub: String?, tint: Color
    ) -> some View {
        SignPanel(tint: tint) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.sm) {
                    if let code = live.currentProvinceCode {
                        PlateBadge(code, onDark: true)
                    }
                    Text(label).font(.signLabel).signCaps().foregroundStyle(.white.opacity(0.9))
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right").font(.system(size: 11, weight: .black))
                        Text(Format.distance(live.distanceMeters))
                            .font(.system(size: 13, weight: .heavy)).monospacedDigit()
                    }
                    .foregroundStyle(.white.opacity(0.9))
                }
                Text(name)
                    .font(.placeHeadline)
                    .minimumScaleFactor(0.6)
                    .lineLimit(2)
                if let sub {
                    Text(sub)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                }
            }
        }
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
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SignHeader("Places passed")
                    .padding(.horizontal, Spacing.md)
                List(live.passedPlaces) { passed in
                    Button {
                        model.homePath.append(.place(passed.ref))
                        TripController.shared.isActiveTripPresented = false
                    } label: {
                        MilestoneRow(title: passed.name, subtitle: passedDetail(passed)) {
                            TierShield(passed.tierLabel)
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                }
                .listStyle(.plain)
            }
        }
    }

    private func passedDetail(_ passed: LiveTripController.PassedPlace) -> String? {
        var parts: [String] = []
        if let parent = passed.parentName { parts.append(parent) }
        if let population = passed.population {
            parts.append("\(Format.population(population)) \(String(localized: "pop."))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: "  ·  ")
    }
}

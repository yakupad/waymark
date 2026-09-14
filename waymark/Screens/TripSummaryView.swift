//  TripSummaryView.swift
//  waymark
//
//  Spec §10 "Yolculuk özeti": route map, stats, highlights, timeline, share button.

import SwiftUI
import GeoData
import LocationEngine
import TripKit
import Presence
import DesignSystem

enum TripSummarySource {
    case justFinished(summary: TripSummary, tripID: UUID?)
    case stored(id: UUID)
}

@MainActor
@Observable
final class TripSummaryModel {
    private(set) var title: String = ""
    private(set) var route: RouteTrace = .empty
    private(set) var summary = TripSummary()
    private(set) var timeline: [TimelineEntry] = []
    private(set) var startedAt: Date?
    private(set) var endedAt: Date?
    var sharePresented = false

    /// Overall average speed, distance over the full duration — `nil` for a
    /// zero-length duration (shouldn't happen for a finished trip, but Format.speed
    /// would otherwise show a bogus 0 km/h).
    var averageSpeedKmh: Double? {
        guard summary.duration > 0 else { return nil }
        return (summary.distanceMeters / summary.duration) * 3.6
    }

    struct TimelineEntry: Identifiable {
        let id: UUID
        let name: String
        let tierLabel: String
        let enteredAt: Date
        let ref: PlaceRef
        /// Average speed for the leg that ended here — from the previous place (or the
        /// trip's start, for the first entry) to this one. `nil` when there's no earlier
        /// point to measure from (route recording off, or an instant first fix).
        let legSpeedKmh: Double?
    }

    private let env: AppEnvironment
    let source: TripSummarySource

    init(source: TripSummarySource, env: AppEnvironment) {
        self.source = source
        self.env = env
    }

    func load() {
        switch source {
        case .justFinished(let summary, let tripID):
            self.summary = summary
            if let tripID, let record = try? env.tripStore.trip(id: tripID) {
                populate(from: record)
            }
        case .stored(let id):
            guard let record = try? env.tripStore.trip(id: id) else { return }
            populate(from: record)
            self.summary = TripSummary.make(from: record.asTrip()) { [env] ref in
                try? env.resolver.place(for: ref, language: env.language)
            }
        }
    }

    private func populate(from record: TripRecord) {
        route = record.route ?? .empty
        title = record.title ?? String(localized: "Trip")
        startedAt = record.startedAt
        endedAt = record.endedAt

        // Leg speed walks from the trip's first known point (the recorded route's start,
        // when there is one) through each event's own coordinate — not the route trace
        // shown on the map, so it stays correct even when the route was trimmed or deleted.
        var previous: (coordinate: Coordinate, at: Date)?
        if let firstPoint = route.segments.first?.points.first {
            previous = (firstPoint, route.segments.first!.startedAt)
        }
        timeline = record.events.map { event in
            let place = try? env.resolver.place(for: event.place, language: env.language)
            var legSpeedKmh: Double?
            if let previous {
                let seconds = event.enteredAt.timeIntervalSince(previous.at)
                if seconds > 0 {
                    let metersPerSecond = Haversine.distance(previous.coordinate, event.coordinate) / seconds
                    legSpeedKmh = metersPerSecond * 3.6
                }
            }
            previous = (event.coordinate, event.enteredAt)
            return TimelineEntry(
                id: event.id, name: place?.nameLocal ?? "—",
                tierLabel: place?.tierLabel ?? "", enteredAt: event.enteredAt, ref: event.place,
                legSpeedKmh: legSpeedKmh
            )
        }
    }
}

struct TripSummaryView: View {
    let model: AppModel
    @State private var summaryModel: TripSummaryModel
    @Environment(\.dismiss) private var dismiss

    init(source: TripSummarySource, model: AppModel) {
        self.model = model
        _summaryModel = State(initialValue: TripSummaryModel(source: source, env: model.env))
    }

    private var isSheet: Bool {
        if case .justFinished = summaryModel.source { return true }
        return false
    }

    /// Open a place detail. From the just-finished sheet we first close the sheet,
    /// otherwise the push lands on the Home stack hidden behind it (and surprises
    /// the user later). From a pushed history view we just push again.
    private func openPlace(_ ref: PlaceRef) {
        if isSheet {
            model.dismissSummary()
            dismiss()
            model.selectedTab = .home
        }
        model.push(.place(ref))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if !summaryModel.route.isEmpty {
                    RouteMap(route: summaryModel.route)
                        .frame(height: 220)
                        .clipShape(.rect(cornerRadius: Radius.md))
                        .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(.quaternary, lineWidth: 1))
                }
                timeRange
                stats
                highlights
                timeline
            }
            .padding(Spacing.md)
        }
        .background(Color(.systemGroupedBackground))
        .scrollContentBackground(.hidden)
        .navigationTitle(summaryModel.title.isEmpty ? String(localized: "Trip summary") : summaryModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isSheet {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        model.dismissSummary()
                        dismiss()
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Share", systemImage: "square.and.arrow.up") {
                    summaryModel.sharePresented = true
                }
                .disabled(summaryModel.route.isEmpty)
            }
        }
        .sheet(isPresented: $summaryModel.sharePresented) {
            SharePreviewView(route: summaryModel.route, summary: summaryModel.summary, env: model.env)
        }
        .onAppear { summaryModel.load() }
    }

    @ViewBuilder
    private var timeRange: some View {
        if let started = summaryModel.startedAt, let ended = summaryModel.endedAt {
            Text("\(Format.time(started)) – \(Format.time(ended))")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var stats: some View {
        let counts = summaryModel.summary.countsByTier.sorted { $0.key < $1.key }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(counts, id: \.key) { tier, count in
                    StatTile(value: "\(count)", label: tierLabel(tier))
                }
                StatTile(value: "\(summaryModel.summary.settlementCount)", label: "Settlements")
                StatTile(value: Format.distance(summaryModel.summary.distanceMeters), label: "Distance")
                if let avgSpeed = summaryModel.averageSpeedKmh {
                    StatTile(value: Format.speed(kmh: avgSpeed), label: "Avg speed")
                }
            }
        }
    }

    private func tierLabel(_ tier: Tier) -> LocalizedStringKey {
        tier == .first ? "Provinces" : tier == .second ? "Districts" : "Tier \(tier.rawValue)"
    }

    @ViewBuilder
    private var highlights: some View {
        if !summaryModel.summary.highlights.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SignHeader("Highlights")
                ForEach(summaryModel.summary.highlights, id: \.ref) { place in
                    Button {
                        openPlace(place.ref)
                    } label: {
                        Card {
                            MilestoneRow(
                                title: place.nameLocal,
                                subtitle: place.parentName
                            ) {
                                if let population = place.population {
                                    Text("\(Format.population(population)) \(String(localized: "pop."))")
                                        .font(.system(size: 12, weight: .bold)).monospacedDigit()
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var timeline: some View {
        if !summaryModel.timeline.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SignHeader("Timeline")
                ForEach(summaryModel.timeline) { entry in
                    Button {
                        openPlace(entry.ref)
                    } label: {
                        // A fixed-width leading time column keeps the place name starting at
                        // the same x on every row.
                        HStack(spacing: Spacing.md) {
                            Text(entry.enteredAt, format: .dateTime.hour().minute())
                                .font(.system(size: 12, weight: .bold).monospacedDigit())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .frame(width: 50, alignment: .leading)
                            if let legSpeedKmh = entry.legSpeedKmh {
                                SpeedBadge(kmh: legSpeedKmh)
                            }
                            Text(entry.name).font(.system(size: 15, weight: .heavy))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Spacer()
                            TierShield(entry.tierLabel)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

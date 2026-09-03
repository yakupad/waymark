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
    var sharePresented = false

    struct TimelineEntry: Identifiable {
        let id: UUID
        let name: String
        let tierLabel: String
        let enteredAt: Date
        let ref: PlaceRef
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
        timeline = record.events.map { event in
            let place = try? env.resolver.place(for: event.place, language: env.language)
            return TimelineEntry(
                id: event.id, name: place?.nameLocal ?? "—",
                tierLabel: place?.tierLabel ?? "", enteredAt: event.enteredAt, ref: event.place
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

    private var stats: some View {
        let counts = summaryModel.summary.countsByTier.sorted { $0.key < $1.key }
        return HStack(spacing: Spacing.sm) {
            ForEach(counts, id: \.key) { tier, count in
                StatTile(value: "\(count)", label: tierLabel(tier))
            }
            StatTile(value: "\(summaryModel.summary.settlementCount)", label: "Settlements")
            StatTile(value: Format.distance(summaryModel.summary.distanceMeters), label: "Distance")
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
                    HStack(spacing: Spacing.md) {
                        Text(entry.enteredAt, format: .dateTime.hour().minute())
                            .font(.system(size: 12, weight: .bold).monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text(entry.name).font(.system(size: 15, weight: .heavy))
                        Spacer()
                        TierShield(entry.tierLabel)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

//  HistoryView.swift
//  waymark
//
//  Spec §10 "Geçmiş": all trips, each with a mini route preview. Swipe to delete, bulk
//  delete, GPX export (spec 17.6).

import SwiftUI
import UniformTypeIdentifiers
import GeoData
import TripKit
import DesignSystem

@MainActor
@Observable
final class HistoryModel {
    private(set) var trips: [TripListItem] = []
    let env: AppEnvironment

    init(env: AppEnvironment) { self.env = env }

    func reload() {
        trips = ((try? env.tripStore.allTrips()) ?? []).map(TripListItem.init)
    }

    func delete(_ item: TripListItem) {
        guard let record = try? env.tripStore.trip(id: item.id) else { return }
        try? env.tripStore.delete(record)
        reload()
    }

    func deleteAll() {
        try? env.tripStore.deleteAll()
        reload()
    }

    /// GPX for the whole history (spec 17.6 — "verilerim bende kalsın").
    func exportGPX() -> String {
        var gpx = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<gpx version=\"1.1\" creator=\"Waymark\">\n"
        for item in trips {
            guard let record = try? env.tripStore.trip(id: item.id), let route = record.route else { continue }
            gpx += "  <trk><name>\(item.title.xmlEscaped)</name>\n"
            for segment in route.segments {
                gpx += "    <trkseg>\n"
                for point in segment.points {
                    gpx += "      <trkpt lat=\"\(point.latitude)\" lon=\"\(point.longitude)\"></trkpt>\n"
                }
                gpx += "    </trkseg>\n"
            }
            gpx += "  </trk>\n"
        }
        gpx += "</gpx>\n"
        return gpx
    }
}

struct HistoryView: View {
    let model: AppModel
    @State private var history: HistoryModel
    @State private var confirmDeleteAll = false

    init(model: AppModel) {
        self.model = model
        _history = State(initialValue: HistoryModel(env: model.env))
    }

    var body: some View {
        Group {
            if history.trips.isEmpty {
                EmptyStateView(
                    title: "No trips yet",
                    message: "Start a trip from the Home tab.",
                    systemImage: "map"
                )
            } else {
                list
            }
        }
        .navigationTitle("History")
        .toolbar {
            if !history.trips.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        ShareLink(
                            item: history.exportGPX(),
                            preview: SharePreview(String(localized: "Waymark trips (GPX)"))
                        ) {
                            Label("Export GPX", systemImage: "square.and.arrow.up")
                        }
                        Button("Delete all trips", systemImage: "trash", role: .destructive) {
                            confirmDeleteAll = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .confirmationDialog("Delete all trips?", isPresented: $confirmDeleteAll, titleVisibility: .visible) {
            Button("Delete all", role: .destructive) { history.deleteAll() }
        }
        .onAppear { history.reload() }
    }

    private var list: some View {
        List {
            ForEach(history.trips) { trip in
                Button {
                    model.historyPath.append(.tripSummary(trip.id))
                } label: {
                    TripRowView(item: trip)
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        history.delete(trip)
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

private extension String {
    var xmlEscaped: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}

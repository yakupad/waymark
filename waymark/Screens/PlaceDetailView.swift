//  PlaceDetailView.swift
//  waymark
//
//  Spec §10 "Yer detayı": name, hierarchy, population, area, elevation, article text,
//  source link, map. Missing content hides its card (spec İ4).

import SwiftUI
import MapKit
import GeoData
import DesignSystem

@MainActor
@Observable
final class PlaceDetailModel {
    private(set) var place: Place?
    let ref: PlaceRef
    private let env: AppEnvironment

    init(ref: PlaceRef, env: AppEnvironment) {
        self.ref = ref
        self.env = env
    }

    func load() {
        place = try? env.resolver.place(for: ref, language: env.language)
    }
}

struct PlaceDetailView: View {
    @State private var model: PlaceDetailModel

    init(ref: PlaceRef, model: AppModel) {
        _model = State(initialValue: PlaceDetailModel(ref: ref, env: model.env))
    }

    var body: some View {
        Group {
            if let place = model.place {
                content(place)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(model.place?.nameLocal ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.load() }
    }

    private func content(_ place: Place) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                heading(place)
                metrics(place)
                if let article = place.article {
                    articleCard(article)
                }
                map(place)
            }
            .padding(Spacing.md)
        }
        .background(Color(.systemGroupedBackground))
        .scrollContentBackground(.hidden)
    }

    private func heading(_ place: Place) -> some View {
        SignPanel {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    if let parent = place.parentName {
                        Text(parent)
                            .font(.signLabel).signCaps()
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    Spacer()
                    TierShield(place.tierLabel, onDark: true)
                }
                Text(place.nameLocal)
                    .font(.placeHeadline)
                    .minimumScaleFactor(0.6)
                    .lineLimit(2)
                if let localized = place.nameLocalized, localized != place.nameLocal {
                    Text(localized)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
    }

    private struct MetricTile: Identifiable {
        let id: String
        let label: LocalizedStringKey
        let value: String
    }

    @ViewBuilder
    private func metrics(_ place: Place) -> some View {
        let tiles = metricTiles(place)
        if !tiles.isEmpty {
            HStack(spacing: Spacing.sm) {
                ForEach(tiles) { tile in
                    StatTile(value: tile.value, label: tile.label)
                }
            }
        }
    }

    private func metricTiles(_ place: Place) -> [MetricTile] {
        var tiles: [MetricTile] = []
        if let population = place.population {
            tiles.append(.init(id: "pop", label: "Population", value: Format.population(population)))
        }
        if let area = place.areaKm2 {
            tiles.append(.init(id: "area", label: "Area",
                               value: "\(area.formatted(.number.precision(.fractionLength(0)))) km²"))
        }
        if let elevation = place.elevationMeters {
            tiles.append(.init(id: "ele", label: "Elevation", value: "\(elevation.formatted(.number)) m"))
        }
        return tiles
    }

    private func articleCard(_ article: Article) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(article.summary)
                    .font(.callout)
                Link(destination: article.sourceURL) {
                    Label("Source (CC BY-SA)", systemImage: "arrow.up.right.square")
                        .font(.caption)
                }
            }
        }
    }

    private func map(_ place: Place) -> some View {
        Map(initialPosition: .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: place.centroid.latitude, longitude: place.centroid.longitude
            ),
            span: MKCoordinateSpan(latitudeDelta: 0.6, longitudeDelta: 0.6)
        ))) {
            Marker(place.nameLocal, coordinate: CLLocationCoordinate2D(
                latitude: place.centroid.latitude, longitude: place.centroid.longitude
            ))
        }
        .frame(height: 220)
        .clipShape(.rect(cornerRadius: Radius.md))
    }
}

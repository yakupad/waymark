//  Shared.swift
//  waymark
//
//  Small view helpers reused across screens.

import SwiftUI
import MapKit
import GeoData
import TripKit
import LocationEngine
import DesignSystem

/// A lightweight, non-interactive map that draws a route's segments (spec 7.7 render:
/// in-app `MapPolyline`, one per segment). The full share-image render is F7 (P9).
struct RouteMap: View {
    let route: RouteTrace
    var interactive = false
    /// When set, the map follows this coordinate (the live trip's current position) and
    /// drops a marker on it. Otherwise it frames the whole route.
    var follow: Coordinate?

    @State private var camera: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $camera, interactionModes: interactive ? .all : []) {
            ForEach(Array(route.segments.enumerated()), id: \.offset) { _, segment in
                MapPolyline(coordinates: segment.points.map {
                    CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                })
                .stroke(Color.brand, lineWidth: 4)
            }
            if let follow {
                Annotation("", coordinate: CLLocationCoordinate2D(
                    latitude: follow.latitude, longitude: follow.longitude
                )) {
                    Circle()
                        .fill(Color.brand)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(.white, lineWidth: 3))
                        .shadow(radius: 2)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .onChange(of: follow.map(Coord.init)) { _, new in
            guard let new else { return }
            withAnimation {
                camera = .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: new.lat, longitude: new.lon),
                    span: MKCoordinateSpan(latitudeDelta: 0.25, longitudeDelta: 0.25)
                ))
            }
        }
        .onAppear {
            if let follow {
                camera = .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: follow.latitude, longitude: follow.longitude),
                    span: MKCoordinateSpan(latitudeDelta: 0.25, longitudeDelta: 0.25)
                ))
            }
        }
    }

    private struct Coord: Equatable {
        let lat: Double, lon: Double
        init(_ c: Coordinate) { lat = c.latitude; lon = c.longitude }
    }
}

/// A map-free polyline sketch. `ImageRenderer` renders `Map` as blank tiles (spec 7.7),
/// so the shareable image draws the route with `Canvas` instead. The real
/// `MKMapSnapshotter` render is F7 (P9).
struct RouteSketch: View {
    let route: RouteTrace

    var body: some View {
        Canvas { context, size in
            let points = route.segments.flatMap(\.points)
            guard points.count > 1 else { return }
            let lons = points.map(\.longitude)
            let lats = points.map(\.latitude)
            let centreLon = (lons.min()! + lons.max()!) / 2
            let centreLat = (lats.min()! + lats.max()!) / 2
            // uniform scale (keeps aspect); minimum span so a dead-straight route still fills.
            let span = max(lons.max()! - lons.min()!, lats.max()! - lats.min()!, 0.002)
            let inset: CGFloat = 10
            let scale = (min(size.width, size.height) - inset * 2) / CGFloat(span)

            func project(_ c: Coordinate) -> CGPoint {
                CGPoint(
                    x: size.width / 2 + CGFloat(c.longitude - centreLon) * scale,
                    y: size.height / 2 - CGFloat(c.latitude - centreLat) * scale
                )
            }

            for segment in route.segments where segment.points.count > 1 {
                var path = Path()
                path.addLines(segment.points.map(project))
                context.stroke(
                    path, with: .color(.brand),
                    style: .init(lineWidth: 3, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .background(Color(.tertiarySystemFill))
    }
}

struct StatTile: View {
    let value: String
    let label: LocalizedStringKey

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.xs)
        .background(.background.secondary, in: .rect(cornerRadius: Radius.sm))
    }
}

enum Format {
    static func distance(_ meters: Double) -> String {
        Measurement(value: meters, unit: UnitLength.meters)
            .converted(to: .kilometers)
            .formatted(.measurement(width: .abbreviated, usage: .road,
                                    numberFormatStyle: .number.precision(.fractionLength(0...1))))
    }

    static func population(_ value: Int) -> String {
        value.formatted(.number)
    }

    static func duration(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }
}

/// A row summarising a stored trip (Home "recent", History list).
struct TripListItem: Identifiable, Equatable {
    let id: UUID
    let title: String
    let startedAt: Date
    let distanceMeters: Double
    let placeCount: Int
    let route: RouteTrace?

    var hasRoute: Bool { route != nil }

    @MainActor
    init(_ record: TripRecord) {
        id = record.id
        startedAt = record.startedAt
        distanceMeters = record.distanceMeters
        route = record.route
        let events = record.events
        title = record.title
            ?? Trip.autoTitle(from: events) { _ in nil }
            ?? String(localized: "Trip on \(record.startedAt.formatted(date: .abbreviated, time: .omitted))")
        placeCount = Set(events.map(\.place)).count
    }
}

struct TripRowView: View {
    let item: TripListItem

    var body: some View {
        HStack(spacing: Spacing.md) {
            if let route = item.route {
                RoutePreviewThumbnail(tripID: item.id, route: route)
            }
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(item.title)
                    .font(.headline)
                HStack(spacing: Spacing.sm) {
                    Text(item.startedAt, format: .dateTime.day().month().year())
                    Text(verbatim: "·")
                    Text(Format.distance(item.distanceMeters))
                    Text(verbatim: "·")
                    Text("\(item.placeCount) places")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}

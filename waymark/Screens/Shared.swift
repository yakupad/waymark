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
            // white casing under a blue line — reads like a road on the map
            ForEach(Array(route.segments.enumerated()), id: \.offset) { _, segment in
                let coords = segment.points.map {
                    CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                }
                MapPolyline(coordinates: coords).stroke(.white, lineWidth: 8)
                MapPolyline(coordinates: coords).stroke(Color.signBlue, lineWidth: 5)
            }
            if let follow {
                Annotation("", coordinate: CLLocationCoordinate2D(
                    latitude: follow.latitude, longitude: follow.longitude
                )) {
                    Group {
                        if let course {
                            Image(systemName: "location.north.fill")
                                .rotationEffect(.degrees(course))
                        } else {
                            Circle().fill(.white).frame(width: 9, height: 9)
                        }
                    }
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.white)
                    .padding(7)
                    .background(Color.signBlue, in: Circle())
                    .overlay(Circle().stroke(.white, lineWidth: 2.5))
                    .shadow(radius: 2, y: 1)
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

    /// Compass bearing (degrees clockwise from north) of the last leg of the route,
    /// so the marker points the way the traveller is actually heading. `nil` until
    /// there are two distinct points to draw a line between.
    private var course: Double? {
        let points = route.segments.flatMap(\.points)
        guard let end = points.last,
              let start = points.reversed().first(where: { Haversine.distance($0, end) > 8 })
        else { return nil }
        let lat1 = start.latitude * .pi / 180
        let lat2 = end.latitude * .pi / 180
        let dLon = (end.longitude - start.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let deg = atan2(y, x) * 180 / .pi
        return deg < 0 ? deg + 360 : deg
    }
}

/// A compact "a journey from A to B" mark for list rows — an origin ring, a
/// short run, and an arrival chevron. Deterministic and legible at any size,
/// unlike a shrunk-down route trace (spec R10).
struct JourneyGlyph: View {
    var body: some View {
        VStack(spacing: 3) {
            Circle()
                .strokeBorder(Color.signBlue, lineWidth: 2.5)
                .frame(width: 9, height: 9)
            Rectangle()
                .fill(Color.signBlue)
                .frame(width: 2.5, height: 14)
            Image(systemName: "chevron.down")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Color.signBlue)
        }
        .frame(width: 52, height: 52)
        .background(Color.signBlue.opacity(0.07), in: .rect(cornerRadius: Radius.sm))
        .overlay(RoundedRectangle(cornerRadius: Radius.sm).stroke(.quaternary, lineWidth: 1))
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
                let path = Path { $0.addLines(segment.points.map(project)) }
                context.stroke(path, with: .color(.white),
                               style: .init(lineWidth: 6, lineCap: .round, lineJoin: .round))
                context.stroke(path, with: .color(.signBlue),
                               style: .init(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
            }
        }
        .background(Color.signBlue.opacity(0.08))
    }
}

/// Thin wrapper so existing call sites keep working; styled as a sign figure.
struct StatTile: View {
    let value: String
    let label: LocalizedStringKey
    var body: some View { SignStat(value: value, label: label) }
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

    private var detail: String {
        let date = item.startedAt.formatted(.dateTime.day().month().year())
        return "\(date)  ·  \(Format.distance(item.distanceMeters))  ·  \(item.placeCount) \(String(localized: "places"))"
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            JourneyGlyph()
            MilestoneRow(title: item.title, subtitle: detail)
        }
    }
}

//  ShareImageRenderer.swift
//  waymark
//
//  Spec 7.7 / P9: the shareable trip image. `MKMapSnapshotter` renders the map tiles,
//  then Core Graphics draws the (trimmed) route polyline via `snapshot.point(for:)` and
//  paints the stats and the "start and end hidden" badge on top.
//
//  Never `ImageRenderer` around a SwiftUI `Map` — it renders blank tiles (spec 7.7).

import UIKit
import MapKit
import SwiftUI
import GeoData
import TripKit
import DesignSystem

@MainActor
enum ShareImageRenderer {

    struct Stats {
        var distanceMeters: Double
        var provinceCount: Int
        var districtCount: Int
        var settlementCount: Int
        var duration: TimeInterval
    }

    /// Render `route` (already trimmed by the caller) onto a map snapshot.
    /// - Returns: `nil` if the route is empty or the snapshot fails (offline, etc.).
    static func render(
        route: RouteTrace,
        stats: Stats,
        trimmed: Bool,
        size: CGSize = CGSize(width: 1200, height: 900),
        scale: CGFloat = 1
    ) async -> UIImage? {
        let coordinates = route.segments.flatMap(\.points)
        guard coordinates.count > 1 else { return nil }

        let options = MKMapSnapshotter.Options()
        options.region = region(fitting: coordinates)
        options.size = size
        options.scale = scale
        options.pointOfInterestFilter = .excludingAll
        options.traitCollection = UITraitCollection(userInterfaceStyle: .light)

        guard let snapshot = try? await MKMapSnapshotter(options: options).start() else {
            return nil
        }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            snapshot.image.draw(at: .zero)
            drawRoute(route, snapshot: snapshot, in: context.cgContext)
            drawStats(stats, size: size, in: context.cgContext)
            if trimmed {
                drawTrimBadge(size: size, in: context.cgContext)
            }
        }
    }

    // MARK: - Geometry

    private static func region(fitting coordinates: [Coordinate]) -> MKCoordinateRegion {
        let lats = coordinates.map(\.latitude)
        let lons = coordinates.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lons.min()! + lons.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((lats.max()! - lats.min()!) * 1.4, 0.05),
            longitudeDelta: max((lons.max()! - lons.min()!) * 1.4, 0.05)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    // MARK: - Drawing

    private static func drawRoute(
        _ route: RouteTrace, snapshot: MKMapSnapshotter.Snapshot, in context: CGContext
    ) {
        context.setStrokeColor(UIColor(Color.brand).cgColor)
        context.setLineWidth(6)
        context.setLineJoin(.round)
        context.setLineCap(.round)

        for segment in route.segments where segment.points.count > 1 {
            let points = segment.points.map {
                snapshot.point(for: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude))
            }
            context.beginPath()
            context.addLines(between: points)
            context.strokePath()
        }
    }

    private static func drawStats(_ stats: Stats, size: CGSize, in context: CGContext) {
        let line1 = Format.distance(stats.distanceMeters)
        let line2 = String(
            localized: "^[\(stats.provinceCount) province](inflect: true) · ^[\(stats.districtCount) district](inflect: true) · \(Format.duration(stats.duration))",
            comment: "Share image caption — counts and duration"
        )

        let title = NSAttributedString(string: line1, attributes: [
            .font: UIFont.systemFont(ofSize: 34, weight: .bold),
            .foregroundColor: UIColor.label,
        ])
        let subtitle = NSAttributedString(string: line2, attributes: [
            .font: UIFont.systemFont(ofSize: 20, weight: .regular),
            .foregroundColor: UIColor.secondaryLabel,
        ])

        let padding: CGFloat = 28
        let boxWidth = max(title.size().width, subtitle.size().width) + padding * 2
        let boxHeight = title.size().height + subtitle.size().height + padding * 2 + 6
        let box = CGRect(x: padding, y: size.height - boxHeight - padding, width: boxWidth, height: boxHeight)

        let bg = UIBezierPath(roundedRect: box, cornerRadius: 18)
        UIColor.systemBackground.withAlphaComponent(0.92).setFill()
        bg.fill()

        title.draw(at: CGPoint(x: box.minX + padding, y: box.minY + padding))
        subtitle.draw(at: CGPoint(x: box.minX + padding, y: box.minY + padding + title.size().height + 6))
    }

    private static func drawTrimBadge(size: CGSize, in context: CGContext) {
        let text = NSAttributedString(
            string: String(localized: "Start and end hidden"),
            attributes: [
                .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
                .foregroundColor: UIColor.white,
            ]
        )
        let padding: CGFloat = 20
        let textSize = text.size()
        let box = CGRect(
            x: size.width - textSize.width - padding * 3,
            y: padding,
            width: textSize.width + padding * 2,
            height: textSize.height + padding
        )
        let pill = UIBezierPath(roundedRect: box, cornerRadius: box.height / 2)
        UIColor.black.withAlphaComponent(0.55).setFill()
        pill.fill()
        text.draw(at: CGPoint(x: box.minX + padding, y: box.minY + padding / 2))
    }
}

//  RoutePreviewCache.swift
//  waymark
//
//  Spec R10: the history list must not host N live maps. Each trip gets one small
//  route-sketch image, drawn once with Core Graphics (offline, no map tiles) and cached.

import UIKit
import SwiftUI
import GeoData
import TripKit
import DesignSystem

@MainActor
final class RoutePreviewCache {

    static let shared = RoutePreviewCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 200
    }

    func preview(tripID: UUID, route: RouteTrace, size: CGSize) -> UIImage? {
        guard !route.isEmpty else { return nil }
        let key = "\(tripID.uuidString)-\(route.pointCount)-\(Int(size.width))x\(Int(size.height))" as NSString
        if let hit = cache.object(forKey: key) {
            return hit
        }
        let image = Self.draw(route: route, size: size)
        cache.setObject(image, forKey: key)
        return image
    }

    func invalidateAll() {
        cache.removeAllObjects()
    }

    // MARK: - Core Graphics sketch

    static func draw(route: RouteTrace, size: CGSize, lineWidth: CGFloat = 3) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            UIColor.tertiarySystemFill.setFill()
            cg.fill(CGRect(origin: .zero, size: size))

            let points = route.segments.flatMap(\.points)
            guard points.count > 1 else { return }

            let lons = points.map(\.longitude)
            let lats = points.map(\.latitude)
            let centreLon = (lons.min()! + lons.max()!) / 2
            let centreLat = (lats.min()! + lats.max()!) / 2
            let span = max(lons.max()! - lons.min()!, lats.max()! - lats.min()!, 0.002)
            let inset: CGFloat = 8
            let scale = (min(size.width, size.height) - inset * 2) / CGFloat(span)

            func project(_ c: Coordinate) -> CGPoint {
                CGPoint(
                    x: size.width / 2 + CGFloat(c.longitude - centreLon) * scale,
                    y: size.height / 2 - CGFloat(c.latitude - centreLat) * scale
                )
            }

            cg.setStrokeColor(UIColor(Color.brand).cgColor)
            cg.setLineWidth(lineWidth)
            cg.setLineJoin(.round)
            cg.setLineCap(.round)
            for segment in route.segments where segment.points.count > 1 {
                cg.beginPath()
                cg.addLines(between: segment.points.map(project))
                cg.strokePath()
            }
        }
    }
}

/// History-row thumbnail backed by the cache.
struct RoutePreviewThumbnail: View {
    let tripID: UUID
    let route: RouteTrace
    var size = CGSize(width: 84, height: 56)

    var body: some View {
        Group {
            if let image = RoutePreviewCache.shared.preview(tripID: tripID, route: route, size: size) {
                Image(uiImage: image).resizable()
            } else {
                Image(systemName: "map").foregroundStyle(.tertiary)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(.rect(cornerRadius: 8))
    }
}

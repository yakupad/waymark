//  Haversine.swift
//  GeoData
//
//  Great-circle distance helper (spec 7.6 step 5, P2). No CoreLocation dependency so the
//  package stays pure (spec 6.1).

import Foundation

public enum Haversine {
    /// Mean Earth radius in metres (IUGG).
    public static let earthRadiusMeters = 6_371_008.8

    /// Great-circle distance between two coordinates, in metres.
    public static func distance(_ a: Coordinate, _ b: Coordinate) -> Double {
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180

        let sinLat = sin(dLat / 2)
        let sinLon = sin(dLon / 2)
        let h = sinLat * sinLat + cos(lat1) * cos(lat2) * sinLon * sinLon
        return 2 * earthRadiusMeters * asin(min(1, sqrt(h)))
    }

    /// Degrees of latitude that span `meters` — a safe bbox half-height anywhere.
    static func latitudeDegrees(forMeters meters: Double) -> Double {
        meters / (earthRadiusMeters * .pi / 180)
    }

    /// Degrees of longitude that span `meters` at the given latitude. Widens as
    /// |latitude| grows; clamped near the poles (not reachable in v1, kept safe anyway).
    static func longitudeDegrees(forMeters meters: Double, atLatitude latitude: Double) -> Double {
        let cosLat = cos(latitude * .pi / 180)
        guard cosLat > 1e-6 else { return 180 }
        return meters / (earthRadiusMeters * .pi / 180 * cosLat)
    }
}

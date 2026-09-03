//  GPXReplayer.swift
//  LocationEngine
//
//  Reads a GPX track and feeds it into a `PresenceEngine` (spec 12.2). Timestamps are
//  replayed as-is (no real waiting) so a 10-hour route runs in milliseconds and
//  deterministically. Also drives the debug menu's "GPX oynatma" (spec §10).

import Foundation
import GeoData

public struct GPXTrackPoint: Sendable, Equatable {
    public let coordinate: Coordinate
    public let time: Date?

    public init(coordinate: Coordinate, time: Date?) {
        self.coordinate = coordinate
        self.time = time
    }
}

public struct GPXTrack: Sendable {
    public let points: [GPXTrackPoint]

    public init(points: [GPXTrackPoint]) {
        self.points = points
    }

    public static func parse(_ data: Data) throws -> GPXTrack {
        let parser = XMLParser(data: data)
        let handler = GPXParserDelegate()
        parser.delegate = handler
        guard parser.parse() else {
            throw GPXError.malformed(parser.parserError?.localizedDescription ?? "unknown")
        }
        return GPXTrack(points: handler.points)
    }

    public static func parse(contentsOf url: URL) throws -> GPXTrack {
        try parse(Data(contentsOf: url))
    }

    public enum GPXError: Error, Equatable {
        case malformed(String)
    }
}

public struct GPXReplayer {
    /// Accuracy stamped on every synthetic fix (GPX carries no `horizontalAccuracy`).
    public var horizontalAccuracy: Double = 10
    /// Spacing used when a point has no `<time>` element.
    public var syntheticInterval: TimeInterval = 1
    /// Start time used when the whole track lacks `<time>` elements.
    public var syntheticStart: Date = Date(timeIntervalSince1970: 0)

    public init() {}

    /// Feed `track` into `engine`. If `timeSource` is supplied it is advanced to each
    /// fix's timestamp before ingest, so the sample-age filter (spec 7.2) accepts
    /// historical traces.
    @discardableResult
    public func replay(
        _ track: GPXTrack, into engine: PresenceEngine, advancing timeSource: MutableTimeSource? = nil
    ) -> [PlaceEvent] {
        var events: [PlaceEvent] = []
        for sample in samples(from: track) {
            timeSource?.advance(to: sample.timestamp)
            events.append(contentsOf: engine.ingest(sample))
        }
        return events
    }

    /// Resolve every point to a `LocationSample`. A point with no `<time>` is placed
    /// `syntheticInterval` after the previous point (or at `syntheticStart` if it is
    /// the first).
    public func samples(from track: GPXTrack) -> [LocationSample] {
        var previous: Date?
        return track.points.map { point in
            let timestamp = point.time
                ?? (previous?.addingTimeInterval(syntheticInterval) ?? syntheticStart)
            previous = timestamp
            return LocationSample(
                coordinate: point.coordinate,
                horizontalAccuracy: horizontalAccuracy,
                speed: -1,
                timestamp: timestamp
            )
        }
    }
}

// MARK: - XML parsing

private final class GPXParserDelegate: NSObject, XMLParserDelegate {
    private(set) var points: [GPXTrackPoint] = []

    private var currentLat: Double?
    private var currentLon: Double?
    private var currentTime: Date?
    private var readingTime = false
    private var timeText = ""

    // Instance-scoped: the delegate is used synchronously within a single `parse()`.
    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private let isoFormatterNoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    func parser(
        _ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
        qualifiedName qName: String?, attributes attributeDict: [String: String]
    ) {
        switch elementName {
        case "trkpt", "rtept", "wpt":
            currentLat = attributeDict["lat"].flatMap(Double.init)
            currentLon = attributeDict["lon"].flatMap(Double.init)
            currentTime = nil
        case "time":
            readingTime = true
            timeText = ""
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if readingTime { timeText += string }
    }

    func parser(
        _ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch elementName {
        case "time":
            let trimmed = timeText.trimmingCharacters(in: .whitespacesAndNewlines)
            currentTime = isoFormatter.date(from: trimmed)
                ?? isoFormatterNoFraction.date(from: trimmed)
            readingTime = false
        case "trkpt", "rtept", "wpt":
            if let lat = currentLat, let lon = currentLon {
                points.append(
                    GPXTrackPoint(
                        coordinate: Coordinate(latitude: lat, longitude: lon), time: currentTime
                    )
                )
            }
            currentLat = nil
            currentLon = nil
            currentTime = nil
        default:
            break
        }
    }
}

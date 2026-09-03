//  GeometryCache.swift
//  GeoData
//
//  Fixed-capacity LRU cache for decoded polygon rings (spec 7.6: "Geometri cache'i LRU
//  olmalı … kapasite 8"). During a trip the same 2–3 polygons are hit over and over;
//  re-reading and re-decoding the blob every time is wasted work.
//
//  Thread-safe: `SQLiteGeoResolver` is `Sendable` and may be called from any thread.

import Foundation

final class GeometryCache: @unchecked Sendable {
    private let capacity: Int
    private let lock = NSLock()
    private var store: [Int: [PolygonRing]] = [:]
    private var order: [Int] = []   // least-recently-used first

    init(capacity: Int) {
        precondition(capacity > 0, "cache capacity must be positive")
        self.capacity = capacity
    }

    /// Returns the cached rings for `id`, or computes them with `load`, caches, returns.
    /// `load` runs outside the lock is *not* guaranteed — it runs under the lock so two
    /// racing callers never both hit SQLite for the same id. The load closure is cheap
    /// (one indexed row read + decode).
    func rings(for id: Int, load: (Int) throws -> [PolygonRing]) rethrows -> [PolygonRing] {
        lock.lock()
        defer { lock.unlock() }

        if let hit = store[id] {
            touch(id)
            return hit
        }
        let value = try load(id)
        store[id] = value
        order.append(id)
        evictIfNeeded()
        return value
    }

    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        store.removeAll()
        order.removeAll()
    }

    // MARK: - Internals (call under lock)

    private func touch(_ id: Int) {
        if let idx = order.firstIndex(of: id) {
            order.remove(at: idx)
        }
        order.append(id)
    }

    private func evictIfNeeded() {
        while order.count > capacity {
            let victim = order.removeFirst()
            store.removeValue(forKey: victim)
        }
    }
}

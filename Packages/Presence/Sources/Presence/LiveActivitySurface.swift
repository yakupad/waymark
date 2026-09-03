//  LiveActivitySurface.swift
//  Presence
//
//  Production `ActivitySurface` over ActivityKit (spec 8.2). iOS only — guarded so
//  `swift test` still builds on macOS.
//
//  The Live Activity *widget* (lock-screen view + the four Dynamic Island states) lives
//  in an app Widget Extension target, which does not exist yet — that is remaining F6/F8
//  work. `WaymarkActivityAttributes` below is the contract that widget will render.

// ActivityKit's module imports on macOS but its API is unavailable there — gate on the OS.
#if os(iOS)
import Foundation
@preconcurrency import ActivityKit

/// ActivityKit attributes for a trip's Live Activity. `ContentState` is the rendered
/// `LiveActivityState` produced by `PresenceCoordinator`.
public struct WaymarkActivityAttributes: ActivityAttributes, Sendable {
    public typealias ContentState = LiveActivityState

    /// `trip-{tripID}` — matches the notification thread so the system groups them.
    public var tripThread: String

    public init(tripThread: String) {
        self.tripThread = tripThread
    }
}

/// `@MainActor` because ActivityKit's request / update / end must run on the main
/// thread — off it they raise `NSInternalInconsistencyException` ("Call must be made
/// on main thread"), which `try?` does NOT catch. `PresenceCoordinator` is an actor
/// and calls these with `await`, which hops here. `Activity` isn't `Sendable`, so it
/// must never leave this actor — keeping it main-isolated is the clean way.
@available(iOS 16.2, *)
@MainActor
public final class LiveActivitySurface: ActivitySurface {

    private var current: Activity<WaymarkActivityAttributes>?
    private let staleAfter: TimeInterval

    public init(staleAfter: TimeInterval = 90 * 60) {
        self.staleAfter = staleAfter
    }

    public func start(_ state: LiveActivityState, thread: String) async {
        await end(state)
        // `areActivitiesEnabled` reads false spuriously on the Simulator; just
        // attempt the request and let it fail quietly if unsupported.
        current = try? Activity.request(
            attributes: WaymarkActivityAttributes(tripThread: thread),
            content: ActivityContent(state: state, staleDate: Date().addingTimeInterval(staleAfter))
        )
    }

    public func update(_ state: LiveActivityState) async {
        guard let current else { return }
        await current.update(
            ActivityContent(state: state, staleDate: Date().addingTimeInterval(staleAfter))
        )
    }

    public func end(_ state: LiveActivityState) async {
        guard let current else { return }
        await current.end(
            ActivityContent(state: state, staleDate: nil), dismissalPolicy: .default
        )
        self.current = nil
    }
}
#endif

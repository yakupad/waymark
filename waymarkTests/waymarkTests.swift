//
//  waymarkTests.swift
//  waymarkTests
//

import Testing
import Foundation
import GeoData
import LocationEngine
import Presence
@testable import waymark

@MainActor
struct SettingsStoreTests {

    private func store() -> SettingsStore {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        return SettingsStore(defaults: defaults)
    }

    @Test func `Defaults match the spec`() {
        let settings = store()
        #expect(settings.sensitivity == .tier1)          // spec 8.1
        #expect(settings.recordRouteTrace == true)        // spec 7.7
        #expect(settings.quietHoursEnabled == false)      // spec 8.4
        #expect(settings.shareTrimMeters == 1_000)        // spec 7.7 (R8)
    }

    @Test func `Sensitivity persists`() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let a = SettingsStore(defaults: defaults)
        a.sensitivity = .settlement
        let b = SettingsStore(defaults: defaults)
        #expect(b.sensitivity == .settlement)
    }

    @Test func `Quiet hours resolve only when enabled`() {
        let settings = store()
        #expect(settings.quietHours == nil)
        settings.quietHoursEnabled = true
        settings.quietStartHour = 23
        settings.quietEndHour = 7
        #expect(settings.quietHours?.startHour == 23)
    }

    @Test func `gateConfig carries the tuning and quiet hours`() {
        let settings = store()
        settings.quietHoursEnabled = true
        let config = settings.gateConfig
        #expect(config.maxNotificationsPerHour == settings.tuning.maxNotificationsPerHour)
        #expect(config.cooldown == settings.tuning.regionCooldown)
        #expect(config.quietHours != nil)
    }
}

struct DemoRouteTests {
    @Test func `Demo route stays within the bundled pack's geometry and filter limits`() {
        let route = DemoRoute.acrossProvinces
        #expect(route.count > 10)
        #expect(route.allSatisfy { $0.latitude == 39.0 })
        #expect(route.first!.longitude == 31.5)
        // consecutive steps under 60 m/s at the demo's 120 s spacing
        for (a, b) in zip(route, route.dropFirst()) {
            let metres = Haversine.distance(a, b)
            #expect(metres / 120 < 60)
        }
    }
}

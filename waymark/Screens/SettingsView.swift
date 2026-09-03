//  SettingsView.swift
//  waymark
//
//  Spec §10 "Ayarlar": sensitivity, route-trace switch, trim distance, quiet hours,
//  permissions, attribution, debug menu.

import SwiftUI
import CoreLocation
import LocationEngine
import Presence
import DesignSystem

struct SettingsView: View {
    let model: AppModel
    @State private var authStatus: CLAuthorizationStatus = .notDetermined

    private var env: AppEnvironment { model.env }

    var body: some View {
        @Bindable var settings = env.settings

        Form {
            Section {
                Picker("Notify me about", selection: $settings.sensitivity) {
                    Text("Provinces only").tag(NotificationSensitivity.tier1)
                    Text("Provinces & districts").tag(NotificationSensitivity.tier2)
                    Text("Every place").tag(NotificationSensitivity.settlement)
                }
                .onChange(of: settings.sensitivity) { _, new in
                    Task { await env.presence.setSensitivity(new) }
                }
            } header: {
                Text("Notifications")
            } footer: {
                Text(sensitivityWarning(settings.sensitivity))
            }

            Section {
                Toggle("Record route trace", isOn: $settings.recordRouteTrace)
            } footer: {
                Text("When off, only the places you pass and the total distance are kept.")
            }

            Section("Quiet hours") {
                Toggle("Silence notifications overnight", isOn: $settings.quietHoursEnabled)
                if settings.quietHoursEnabled {
                    Stepper(value: $settings.quietStartHour, in: 0...23) {
                        Text("From \(settings.quietStartHour):00")
                    }
                    Stepper(value: $settings.quietEndHour, in: 0...23) {
                        Text("Until \(settings.quietEndHour):00")
                    }
                }
            }
            .onChange(of: settings.quietHours) { _, new in
                Task { await env.presence.setQuietHours(new) }
            }

            Section("Permissions") {
                LabeledContent("Location", value: authDescription)
                if authStatus == .notDetermined {
                    Button("Request location access") {
                        (env.locationProvider as? CoreLocationProvider)?.requestWhenInUseAuthorization()
                    }
                }
                Button("Request notification access") {
                    Task { _ = await UserNotificationSurface().requestAuthorization() }
                }
            }

            Section {
                NavigationLink("Data sources & licenses", value: AppRoute.about)
            }

            #if DEBUG
            Section {
                NavigationLink("Debug menu", value: AppRoute.debug)
            }
            #endif
        }
        .navigationTitle("Settings")
        .onAppear { authStatus = env.locationProvider.authorizationStatus }
    }

    private func sensitivityWarning(_ sensitivity: NotificationSensitivity) -> LocalizedStringKey {
        switch sensitivity {
        case .tier1:
            "A notification only when you cross into a new province — a handful on a long drive."
        case .tier2:
            "A notification for each new province and district. Recommended for most trips."
        case .settlement:
            "Also every village and town you pass — this can be a lot on a long drive."
        }
    }

    private var authDescription: String {
        switch authStatus {
        case .authorizedAlways: String(localized: "Always")
        case .authorizedWhenInUse: String(localized: "While using the app")
        case .denied, .restricted: String(localized: "Denied")
        default: String(localized: "Not requested")
        }
    }
}

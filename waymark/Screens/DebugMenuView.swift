//  DebugMenuView.swift
//  waymark
//
//  Spec §10 debug menu (DEBUG builds only): live PresenceTuning, inject fake location,
//  GPX playback, machine states, pack info.

#if DEBUG
import SwiftUI
import GeoData
import LocationEngine
import DesignSystem

struct DebugMenuView: View {
    let model: AppModel
    @State private var lat = 39.0
    @State private var lon = 32.0

    private var env: AppEnvironment { model.env }

    var body: some View {
        @Bindable var settings = env.settings

        Form {
            Section("Presence tuning") {
                tuningSlider("Confirm dwell (s)", value: $settings.tuning.confirmDwellTime, range: 10...180)
                tuningSlider("Confirm distance (m)", value: $settings.tuning.confirmDwellDistance, range: 200...5_000)
                tuningSlider("Exit buffer (m)", value: $settings.tuning.exitBufferDistance, range: 100...2_000)
                tuningSlider("Exit dwell (s)", value: $settings.tuning.exitDwellTime, range: 10...300)
                tuningSlider("Settlement radius (m)", value: $settings.tuning.settlementRadius, range: 200...5_000)
            }

            Section("Inject location") {
                LabeledContent("Latitude") {
                    TextField("lat", value: $lat, format: .number).multilineTextAlignment(.trailing)
                }
                LabeledContent("Longitude") {
                    TextField("lon", value: $lon, format: .number).multilineTextAlignment(.trailing)
                }
                Button("Send fix") {
                    (env.locationProvider as? SimulatedLocationProvider)?
                        .inject(Coordinate(latitude: lat, longitude: lon))
                }
                .disabled(!(env.locationProvider is SimulatedLocationProvider))
            }

            Section("Playback") {
                Button("Play demo route") {
                    (env.locationProvider as? SimulatedLocationProvider)?
                        .load(DemoRoute.acrossProvinces, spacing: 40)
                    env.locationProvider.startTracking(configuration: .init())
                }
                .disabled(!(env.locationProvider is SimulatedLocationProvider))
            }

            Section("Live state") {
                LabeledContent("Running", value: model.liveTrip.isRunning ? "yes" : "no")
                LabeledContent("Current place", value: model.liveTrip.headline ?? "—")
                LabeledContent("Places passed", value: "\(model.liveTrip.passedPlaces.count)")
                LabeledContent("Distance", value: Format.distance(model.liveTrip.distanceMeters))
            }

            Section("Pack") {
                LabeledContent("Tiers", value: tierSummary)
                Text("Bundled pack is the F1 synthetic fixture — real Turkey data lands with F1.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Debug")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func tuningSlider(
        _ label: LocalizedStringKey, value: Binding<Double>, range: ClosedRange<Double>
    ) -> some View {
        VStack(alignment: .leading) {
            LabeledContent(label) {
                Text(value.wrappedValue, format: .number.precision(.fractionLength(0)))
            }
            Slider(value: value, in: range)
        }
    }

    private var tierSummary: String {
        ((try? env.resolver.tierLabels()) ?? [])
            .map { "\($0.tier.rawValue):\($0.labelLocal)" }
            .joined(separator: " ")
    }
}
#endif

//  TripLiveActivity.swift
//  WaymarkWidgets
//
//  The trip Live Activity (spec 8.2): lock-screen view + the four Dynamic Island states.
//  `ContentState` is `Presence.LiveActivityState`, produced by `PresenceCoordinator`.

import WidgetKit
import SwiftUI
import ActivityKit
import Presence
import DesignSystem

struct TripLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WaymarkActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .padding(Spacing.md)
                .activityBackgroundTint(Color.black.opacity(0.35))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.state.headline).font(.headline).lineLimit(1)
                    } icon: {
                        Image(systemName: "signpost.right.fill").foregroundStyle(.tint)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let population = context.state.population {
                        Text("\(population, format: .number)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.state.hierarchy)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                        TripCountChips(state: context.state)
                    }
                }
            } compactLeading: {
                Image(systemName: "signpost.right.fill")
            } compactTrailing: {
                Text(context.state.headline)
                    .lineLimit(1)
                    .frame(maxWidth: 84)
            } minimal: {
                Image(systemName: "signpost.right.fill")
            }
            .keylineTint(.brand)
        }
    }
}

private struct LockScreenView: View {
    let state: LiveActivityState

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(state.headline)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .lineLimit(1)
                Spacer()
                if let population = state.population {
                    Text("\(population, format: .number)")
                        .font(.callout.monospacedDigit().weight(.semibold))
                }
            }
            Text(state.hierarchy)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Divider().opacity(0.4)
            TripCountChips(state: state)
        }
        .foregroundStyle(.white)
    }
}

private struct TripCountChips: View {
    let state: LiveActivityState

    private var ordered: [(tier: Int, count: Int)] {
        state.tierCounts.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(ordered, id: \.tier) { entry in
                chip("\(entry.count)", label: tierLabel(entry.tier))
            }
            if state.settlementCount > 0 {
                chip("\(state.settlementCount)", label: "towns")
            }
        }
        .font(.caption2)
    }

    private func chip(_ value: String, label: LocalizedStringKey) -> some View {
        HStack(spacing: 2) {
            Text(value).fontWeight(.semibold).monospacedDigit()
            Text(label).foregroundStyle(.secondary)
        }
    }

    private func tierLabel(_ tier: Int) -> LocalizedStringKey {
        tier == 1 ? "provinces" : tier == 2 ? "districts" : "areas"
    }
}

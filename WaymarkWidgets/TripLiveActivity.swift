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
                    if let code = context.state.provinceCode {
                        PlateBadge(code, onDark: true)
                    } else if let population = context.state.population {
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
            HStack(alignment: .top, spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "location.north.fill")
                            .font(.system(size: 13, weight: .black))
                        Text(state.headline)
                            .font(.system(size: 22, weight: .black))
                            .lineLimit(1)
                    }
                    Text(state.hierarchy)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: Spacing.sm)
                if let code = state.provinceCode {
                    // Plate, sized like the place name — the way an il-sınırı sign reads.
                    Text(code)
                        .font(.system(size: 22, weight: .black).monospacedDigit())
                        .tracking(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.white, in: RoundedRectangle(cornerRadius: 5))
                        .foregroundStyle(Color.signBlue)
                }
            }
            Divider().opacity(0.4)
            HStack {
                TripCountChips(state: state)
                if let population = state.population {
                    Spacer()
                    Text("\(population, format: .number)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
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

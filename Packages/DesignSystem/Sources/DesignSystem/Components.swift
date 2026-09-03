//  Components.swift
//  DesignSystem
//
//  Shared building blocks, styled as road signage (spec §10).

import SwiftUI

// MARK: - Direction panel

/// The white-on-blue direction panel — the "where you are" hero. Carries the thin
/// white keyline that Turkish intercity signs use.
public struct SignPanel<Content: View>: View {
    private let tint: Color
    private let content: Content

    public init(tint: Color = .signBlue, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    private var gradientEnd: Color {
        tint == .signBlue ? .signBlueDeep : tint.opacity(0.78)
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.lg)
            .background(
                LinearGradient(
                    colors: [tint, gradientEnd],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: Radius.lg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg - 5)
                    .inset(by: 7)
                    .stroke(.white.opacity(0.85), lineWidth: 1.75)
            )
            .foregroundStyle(.white)
    }
}

// MARK: - Tier shield

/// A small outlined badge for a tier label — İL / İLÇE / KÖY.
public struct TierShield: View {
    private let text: String
    private let onDark: Bool

    public init(_ text: String, onDark: Bool = false) {
        self.text = text
        self.onDark = onDark
    }

    public var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy))
            .signCaps(1.0)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(onDark ? Color.white : Color.signBlue, lineWidth: 1.5)
            )
            .foregroundStyle(onDark ? Color.white : Color.signBlue)
            .fixedSize()
    }
}

// MARK: - Section header

/// An uppercase, tracked section header with a leading rule.
public struct SignHeader: View {
    private let title: LocalizedStringKey

    public init(_ title: LocalizedStringKey) { self.title = title }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            Text(title)
                .font(.signLabel)
                .signCaps()
                .foregroundStyle(.secondary)
            Rectangle()
                .fill(.quaternary)
                .frame(height: 1)
        }
    }
}

// MARK: - Card

/// A plain surface card — a hairline keeps it distinct from the grouped ground.
public struct Card<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
            .background(.background.secondary, in: .rect(cornerRadius: Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(.quaternary, lineWidth: 1)
            )
    }
}

// MARK: - Primary button

/// The primary call-to-action — a solid blue sign with an uppercase legend.
public struct PrimaryButton: View {
    private let title: LocalizedStringKey
    private let systemImage: String?
    private let action: () -> Void

    public init(
        _ title: LocalizedStringKey, systemImage: String? = nil, action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if let systemImage {
                    Image(systemName: systemImage).font(.system(size: 16, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 17, weight: .heavy))
                    .signCaps(0.6)
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .black))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md + 2)
            .background(
                LinearGradient(
                    colors: [.signBlue, .signBlueDeep],
                    startPoint: .top, endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: Radius.md)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Distance / count figure

/// A figure set like the kilometres on a direction sign: big number, small
/// uppercase legend beneath, a rule on top.
public struct SignStat: View {
    private let value: String
    private let label: LocalizedStringKey

    public init(value: String, label: LocalizedStringKey) {
        self.value = value
        self.label = label
    }

    public var body: some View {
        VStack(spacing: Spacing.xs) {
            Rectangle().fill(Color.signBlue).frame(height: 2)
            Text(value)
                .font(.system(size: 20, weight: .black).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .signCaps()
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.xs)
        .padding(.bottom, Spacing.sm)
        .padding(.horizontal, Spacing.xs)
    }
}

// MARK: - Milestone row

/// A list row for a passed place or a stored trip — a leading chevron like the
/// ones stencilled on a kerbstone, then the name, then trailing detail.
public struct MilestoneRow<Trailing: View>: View {
    private let title: String
    private let subtitle: String?
    private let trailing: Trailing

    public init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(Color.signBlue)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .heavy))
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: Spacing.sm)
            trailing
        }
    }
}

// MARK: - Metric badge (kept)

public struct MetricBadge: View {
    private let label: LocalizedStringKey
    private let value: String

    public init(_ label: LocalizedStringKey, value: String) {
        self.label = label
        self.value = value
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label).font(.signLabel).signCaps().foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.bold)).monospacedDigit()
        }
    }
}

// MARK: - Empty state

public struct EmptyStateView: View {
    private let title: LocalizedStringKey
    private let message: LocalizedStringKey
    private let systemImage: String

    public init(
        title: LocalizedStringKey, message: LocalizedStringKey, systemImage: String
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
    }

    public var body: some View {
        ContentUnavailableView {
            Label { Text(title) } icon: { Image(systemName: systemImage) }
        } description: {
            Text(message)
        }
    }
}

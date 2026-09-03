//  Components.swift
//  DesignSystem
//
//  Shared building blocks used across screens (spec §10).

import SwiftUI

/// A rounded surface card. Content decides its own padding via `Spacing`.
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
    }
}

/// The primary call-to-action button (Home's "Start a trip").
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
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
        }
        .buttonStyle(.borderedProminent)
        .tint(.brand)
        .controlSize(.large)
    }
}

/// A small population / distance badge.
public struct MetricBadge: View {
    private let label: LocalizedStringKey
    private let value: String

    public init(_ label: LocalizedStringKey, value: String) {
        self.label = label
        self.value = value
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
        }
    }
}

/// Empty-state placeholder for lists.
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
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage)
            }
        } description: {
            Text(message)
        }
    }
}

//  SharePreviewView.swift
//  waymark
//
//  Spec §10 "Paylaşım önizleme": generated image, trim-distance control, "start and end
//  hidden" badge. The shareable image is produced by `ShareImageRenderer`
//  (`MKMapSnapshotter` + Core Graphics, spec 7.7); the on-screen preview is a fast
//  `Canvas` sketch that updates instantly as the trim changes.

import SwiftUI
import GeoData
import LocationEngine
import TripKit
import DesignSystem

struct SharePreviewView: View {
    let route: RouteTrace
    let summary: TripSummary
    let env: AppEnvironment

    @Environment(\.dismiss) private var dismiss
    @State private var trimMeters: Double
    @State private var rendered: RenderState = .idle

    private let trimOptions: [Double] = [0, 500, 1_000, 2_000]

    private enum RenderState: Equatable {
        case idle, rendering, ready(Image), failed
    }

    init(route: RouteTrace, summary: TripSummary, env: AppEnvironment) {
        self.route = route
        self.summary = summary
        self.env = env
        _trimMeters = State(initialValue: env.settings.shareTrimMeters)
    }

    private var trimmedRoute: RouteTrace {
        route.trimmed(by: trimMeters)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.md) {
                preview
                if trimMeters > 0 {
                    Label("Start and end hidden", systemImage: "eye.slash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Picker("Trim ends", selection: $trimMeters) {
                    ForEach(trimOptions, id: \.self) { meters in
                        Text(meters == 0 ? String(localized: "Off") : Format.distance(meters))
                            .tag(meters)
                    }
                }
                .pickerStyle(.segmented)

                shareButton
                Spacer(minLength: 0)
            }
            .padding(Spacing.md)
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        env.settings.shareTrimMeters = trimMeters
                        dismiss()
                    }
                }
            }
            .task(id: trimMeters) { await renderShareImage() }
        }
    }

    private var preview: some View {
        RouteSketch(route: trimmedRoute)
            .frame(height: 300)
            .clipShape(.rect(cornerRadius: Radius.md))
            .overlay(alignment: .bottomLeading) { previewCaption }
            .overlay(alignment: .bottomTrailing) {
                if trimmedRoute.isEmpty {
                    Text("Route too short to trim", comment: "Shown when trim removes the whole route")
                        .font(.caption)
                        .padding(Spacing.sm)
                        .background(.regularMaterial, in: .capsule)
                        .padding(Spacing.sm)
                }
            }
    }

    private var previewCaption: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(Format.distance(summary.distanceMeters)).font(.title3.weight(.bold))
            Text("^[\(summary.countsByTier[.first] ?? 0) province](inflect: true) · ^[\(summary.countsByTier[.second] ?? 0) district](inflect: true) · \(Format.duration(summary.duration))", comment: "Share preview caption — mirrors the rendered image")
                .font(.caption)
        }
        .padding(Spacing.sm)
        .background(.regularMaterial, in: .rect(cornerRadius: Radius.sm))
        .padding(Spacing.md)
    }

    @ViewBuilder
    private var shareButton: some View {
        switch rendered {
        case .ready(let image):
            ShareLink(
                item: image,
                preview: SharePreview(String(localized: "My Waymark trip"), image: image)
            ) {
                Label("Share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.brand)
            .controlSize(.large)
        case .rendering, .idle:
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, Spacing.sm)
        case .failed:
            Text("Couldn't build the image (you may be offline).", comment: "Share image render failure")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func renderShareImage() async {
        guard !trimmedRoute.isEmpty else { rendered = .failed; return }
        rendered = .rendering
        let stats = ShareImageRenderer.Stats(
            distanceMeters: summary.distanceMeters,
            provinceCount: summary.countsByTier[.first] ?? 0,
            districtCount: summary.countsByTier[.second] ?? 0,
            settlementCount: summary.settlementCount,
            duration: summary.duration
        )
        let image = await ShareImageRenderer.render(
            route: trimmedRoute, stats: stats, trimmed: trimMeters > 0
        )
        if let image {
            rendered = .ready(Image(uiImage: image))
        } else {
            rendered = .failed
        }
    }
}

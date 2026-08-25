//
//  MediaCardView.swift
//  TMinus
//
//  Created by Sadegh on 13/08/2026.
//

import SwiftUI

/// Shared chrome for a tappable list row with a leading thumbnail, background, border, corner
/// radius, the `AsyncImage` phase-switch and placeholder, and the accessibility-combine grouping.
/// `LaunchCardView` and `NewsCardView` were previously two independent, structurally-identical
/// implementations of exactly this; only the trailing info content actually differs per feature,
/// so that's the one thing left as a parameter.
struct MediaCardView<Content: View>: View {
    let imageURL: URL?
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: UIConstants.Spacing.medium) {
            thumbnailView
            content()
        }
        .padding(UIConstants.Padding.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundView)
        .overlay(overlayView)
        // Merges the info content into a single VoiceOver announcement instead of several
        // separate swipe stops for what's really one tappable row; the thumbnail is hidden below
        // rather than combined, since it has no accessible description of its own.
        .accessibilityElement(children: .combine)
    }

    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: UIConstants.CornerRadius.card, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
    }

    private var overlayView: some View {
        RoundedRectangle(cornerRadius: UIConstants.CornerRadius.card, style: .continuous)
            .stroke(Color.primary.opacity(UIConstants.Border.opacity), lineWidth: UIConstants.Border.lineWidth)
    }

    private var thumbnailView: some View {
        RemoteImagePhaseView(imageURL: imageURL)
            .frame(width: UIConstants.Layout.thumbnailSize, height: UIConstants.Layout.thumbnailSize)
            .clipShape(RoundedRectangle(cornerRadius: UIConstants.CornerRadius.image, style: .continuous))
            // Purely decorative, the API gives no alt text for these images, and the row's
            // title is already announced from the info content, so an unlabelled "Image" would
            // only add noise.
            .accessibilityHidden(true)
    }
}

// MARK: - Previews

#Preview("With image") {
    MediaCardView(imageURL: URL(string: "https://example.com/image.jpg")) {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.small) {
            Text("Card Title")
                .font(.headline)
            Text("Some secondary metadata")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    .padding()
    .environment(\.imageDataLoader, PreviewImageDataLoader())
}

#Preview("No image") {
    MediaCardView(imageURL: nil) {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.small) {
            Text("Card Title")
                .font(.headline)
            Text("Some secondary metadata")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    .padding()
}

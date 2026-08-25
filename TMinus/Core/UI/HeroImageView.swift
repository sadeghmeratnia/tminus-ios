//
//  HeroImageView.swift
//  TMinus
//
//  Created by Sadegh on 14/08/2026.
//

import SwiftUI

/// A full-width, fixed-height hero image for a detail screen's header, `LaunchDetailView` and
/// `NewsDetailView` previously each hand-rolled an identical `AsyncImage` block that collapsed
/// `.failure` and `.empty` into the same bare tinted rectangle, unlike `MediaCardView`'s
/// thumbnail, which explicitly shows a "broken photo" icon on `.failure`. This gives detail
/// screens the same explicit failure state, and removes the duplication between the two.
struct HeroImageView: View {
    let imageURL: URL?

    var body: some View {
        RemoteImagePhaseView(imageURL: imageURL)
            .frame(maxWidth: .infinity)
            .frame(height: UIConstants.Layout.heroHeight)
            .clipShape(RoundedRectangle(cornerRadius: UIConstants.CornerRadius.card, style: .continuous))
            // Purely decorative, the screen's title/metadata already follow immediately below,
            // so an unlabelled "Image" would only add noise.
            .accessibilityHidden(true)
    }
}

// MARK: - Previews

#Preview("With image") {
    HeroImageView(imageURL: URL(string: "https://example.com/image.jpg"))
        .padding()
        .environment(\.imageDataLoader, PreviewImageDataLoader())
}

#Preview("No image") {
    HeroImageView(imageURL: nil)
        .padding()
}

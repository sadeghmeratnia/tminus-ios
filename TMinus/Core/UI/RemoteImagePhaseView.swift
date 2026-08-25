//
//  RemoteImagePhaseView.swift
//  TMinus
//
//  Created by Sadegh on 16/08/2026.
//

import SwiftUI
import UIKit

/// Shared loading, failure and placeholder states for card and hero images.
/// Uses the app's image loader so requests share its cache, retry and logging behavior.
struct RemoteImagePhaseView: View {
    let imageURL: URL?

    @Environment(\.imageDataLoader) private var imageDataLoader
    @State private var phase: Phase = .loading

    var body: some View {
        content
            // Re-runs (and cancels any in-flight fetch for the previous URL) whenever `imageURL`
            // changes, e.g. a recycled list row bound to a new item, rather than leaving a
            // stale fetch racing to overwrite this row's now-current image.
            .task(id: imageURL) {
                await load()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case let .loaded(image):
            image
                .resizable()
                .scaledToFill()
        case .failure:
            placeholderImage
        case .loading, .empty:
            Rectangle()
                .fill(Color.secondary.opacity(UIConstants.Opacity.subtleBackground))
        }
    }

    private var placeholderImage: some View {
        ZStack {
            Rectangle()
                .fill(Color.secondary.opacity(UIConstants.Opacity.subtleBackground))

            Image(systemName: UIConstants.Icon.photoPlaceholder)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private func load() async {
        guard let imageURL else {
            phase = .empty
            return
        }
        phase = .loading
        do {
            let data = try await imageDataLoader.data(for: imageURL)
            guard let uiImage = await decodeImage(from: data) else {
                // Checked here too, not just on the success path below: `imageDataLoader.data`
                // can return (e.g. served from cache) after this task was already superseded by
                // a newer `imageURL`, and a decode failure on that stale data must not clobber
                // the phase a newer, still-running `load()` may have already committed.
                try Task.checkCancellation()
                phase = .failure
                return
            }
            try Task.checkCancellation()
            phase = .loaded(Image(uiImage: uiImage))
        } catch is CancellationError {
            // Superseded by a newer `imageURL`; that task's own `load()` owns `phase` now.
        } catch {
            phase = .failure
        }
    }
}

/// Runs off the MainActor so decoding a larger photo never blocks scrolling/animation. A free
/// function (rather than a method on the non-`Sendable` `RemoteImagePhaseView`) so hopping
/// executors doesn't require sending a non-`Sendable` `self` across the boundary.
@concurrent
private func decodeImage(from data: Data) async -> UIImage? {
    UIImage(data: data)
}

// MARK: - RemoteImagePhaseView.Phase

private extension RemoteImagePhaseView {
    enum Phase {
        case loading
        case loaded(Image)
        case failure
        /// No `imageURL` was provided, a legitimate state, distinct from a fetch/decode
        /// failure, so it renders the plain tinted rectangle rather than the "broken photo" icon.
        case empty
    }
}

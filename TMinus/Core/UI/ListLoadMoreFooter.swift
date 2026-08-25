//
//  ListLoadMoreFooter.swift
//  TMinus
//
//  Created by Sadegh on 13/07/2026.
//

import SwiftUI

/// Renders the trailing pagination state of any list, a spinner while the next page loads, an
/// error+retry footer if it failed, or nothing while idle. Shared so the branching itself (not
/// just the error footer's layout) isn't reimplemented per feature list.
struct ListLoadMoreFooter: View {
    let isLoadingMore: Bool
    let loadMoreError: String?
    let retryTitle: String
    let onRetry: () -> Void

    var body: some View {
        if isLoadingMore {
            // Labeled, unlike a bare `ProgressView()`, `ListScreenScaffold`'s initial-load
            // spinner already carries a localized title VoiceOver announces; this pagination
            // footer's spinner previously didn't, so a VoiceOver user scrolling to the bottom of
            // a list got no announcement that more items were loading.
            ProgressView(L10n.Common.loadingMore)
                .frame(maxWidth: .infinity)
        } else if let loadMoreError {
            ListLoadMoreErrorFooter(message: loadMoreError, retryTitle: retryTitle, onRetry: onRetry)
        }
    }
}

// MARK: - Previews

#Preview("Loading more") {
    ListLoadMoreFooter(isLoadingMore: true, loadMoreError: nil, retryTitle: "Retry", onRetry: {})
        .padding()
}

#Preview("Error") {
    ListLoadMoreFooter(isLoadingMore: false, loadMoreError: "Could not load more results.", retryTitle: "Retry", onRetry: {})
        .padding()
}

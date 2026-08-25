//
//  ListScreenScaffold.swift
//  TMinus
//
//  Created by Sadegh on 13/07/2026.
//

import SwiftUI

/// Renders the loading/error/empty states shared by every paginated list screen, deferring to
/// `content` only once `phase` is `.content`. Shared so a feature's list view only has to define
/// what its populated list looks like, not re-derive the same three placeholder screens.
struct ListScreenScaffold<Item, Content: View>: View {
    let phase: ListContentPhase<Item>
    let loadingTitle: String
    let errorTitle: String
    let emptyTitle: String
    let emptyDescription: String
    let emptyIcon: String
    /// Retries the load that produced this full-screen error or empty state, paired with its
    /// button's title as one value so a caller can't supply one half without the other, `nil`
    /// (the default) omits the retry button entirely. Also surfaced on `.empty`: a genuinely
    /// empty (or stale-empty-cache) result would otherwise have no way to force a refresh short
    /// of navigating away and back, since `.refreshable` only applies once `phase` is `.content`.
    var retry: (title: String, action: () -> Void)?
    @ViewBuilder let content: () -> Content

    var body: some View {
        switch phase {
        case .loading:
            ProgressView(loadingTitle)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case let .error(message):
            ContentUnavailableView {
                Label(errorTitle, systemImage: UIConstants.Icon.networkError)
            } description: {
                Text(message)
            } actions: {
                if let retry {
                    Button(retry.title, action: retry.action)
                        .accessibilityIdentifier(Constants.AccessibilityID.retryButton)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .empty:
            // A genuinely-empty result (or a stale empty cache from just before new items became
            // available) otherwise has no way to force a refresh short of switching tabs or
            // backgrounding the app, `.refreshable` is only attached once `phase` is `.content`.
            ContentUnavailableView {
                Label(emptyTitle, systemImage: emptyIcon)
            } description: {
                Text(emptyDescription)
            } actions: {
                if let retry {
                    Button(retry.title, action: retry.action)
                        .accessibilityIdentifier(Constants.AccessibilityID.retryButton)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .content:
            content()
        }
    }
}

// MARK: - Constants

/// Not nested inside `ListScreenScaffold` (unlike most other views' `Constants`), it's generic,
/// and a generic type can't declare `static let` stored properties.
private enum Constants {
    enum AccessibilityID {
        /// Shared across the `.error`/`.empty` retry buttons, the two are mutually exclusive
        /// phases of the same screen, so a UI test targeting "the retry button" on whichever
        /// screen is currently visible never needs to disambiguate between them.
        static let retryButton = "listScreenScaffoldRetryButton"
    }
}

// MARK: - Previews

#Preview("Loading") {
    ListScreenScaffold<Int, EmptyView>(
        phase: .loading,
        loadingTitle: "Loading…",
        errorTitle: "Could not load",
        emptyTitle: "Nothing here",
        emptyDescription: "Nothing to show right now.",
        emptyIcon: "tray"
    ) { EmptyView() }
}

#Preview("Empty") {
    ListScreenScaffold<Int, EmptyView>(
        phase: .empty,
        loadingTitle: "Loading…",
        errorTitle: "Could not load",
        emptyTitle: "Nothing here",
        emptyDescription: "Nothing to show right now.",
        emptyIcon: "tray"
    ) { EmptyView() }
}

#Preview("Error") {
    ListScreenScaffold<Int, EmptyView>(
        phase: .error(message: "Could not reach the server."),
        loadingTitle: "Loading…",
        errorTitle: "Could not load",
        emptyTitle: "Nothing here",
        emptyDescription: "Nothing to show right now.",
        emptyIcon: "tray"
    ) { EmptyView() }
}

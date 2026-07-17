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
    @ViewBuilder let content: () -> Content

    var body: some View {
        switch phase {
        case .loading:
            ProgressView(loadingTitle)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case let .error(message):
            ContentUnavailableView(
                errorTitle,
                systemImage: UIConstants.Icon.networkError,
                description: Text(message))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .empty:
            ContentUnavailableView(
                emptyTitle,
                systemImage: emptyIcon,
                description: Text(emptyDescription))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .content:
            content()
        }
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
        emptyIcon: "tray") { EmptyView() }
}

#Preview("Empty") {
    ListScreenScaffold<Int, EmptyView>(
        phase: .empty,
        loadingTitle: "Loading…",
        errorTitle: "Could not load",
        emptyTitle: "Nothing here",
        emptyDescription: "Nothing to show right now.",
        emptyIcon: "tray") { EmptyView() }
}

#Preview("Error") {
    ListScreenScaffold<Int, EmptyView>(
        phase: .error(message: "Could not reach the server."),
        loadingTitle: "Loading…",
        errorTitle: "Could not load",
        emptyTitle: "Nothing here",
        emptyDescription: "Nothing to show right now.",
        emptyIcon: "tray") { EmptyView() }
}

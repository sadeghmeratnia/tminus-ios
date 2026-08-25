//
//  NewsListView.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import SwiftUI

// MARK: - NewsListView

struct NewsListView<VM: NewsListViewModelProtocol>: View {
    @ObservedObject var viewModel: VM
    let onArticleSelected: (String) -> Void

    private var state: NewsListState {
        viewModel.state
    }

    private var articles: [NewsArticle] {
        state.articles
    }

    private var resolvedContent: (phase: ListContentPhase<NewsArticle>, refreshErrorMessage: String?) {
        ListContentPhase.resolve(phase: state.phase, items: articles)
    }

    private var searchBinding: Binding<String> {
        Binding(
            get: { state.searchText },
            set: { viewModel.onTrigger(.searchTextChanged($0)) }
        )
    }

    var body: some View {
        let (phase, refreshErrorMessage) = resolvedContent
        let isSearching = state.searchText.isEmpty == false
        return ListScreenScaffold(
            phase: phase,
            loadingTitle: L10n.News.loading,
            errorTitle: L10n.News.errorTitle,
            emptyTitle: isSearching ? L10n.News.noResultsTitle : L10n.News.emptyTitle,
            emptyDescription: isSearching ? L10n.News.noResultsDescription : L10n.News.emptyDescription,
            emptyIcon: isSearching ? Constants.Icon.noResults : Constants.Icon.empty,
            retry: (title: L10n.News.retryAction, action: { viewModel.onTrigger(.retry) })
        ) {
            articlesListView(bannerMessage: refreshErrorMessage)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(L10n.News.navigationTitle)
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: searchBinding, prompt: L10n.News.searchPrompt)
        .task { viewModel.onTrigger(.onAppear) }
        .onDisappear { viewModel.cancelInFlightWork() }
    }

    private func articlesListView(bannerMessage: String?) -> some View {
        ScrollView {
            LazyVStack(spacing: UIConstants.Spacing.large) {
                if let bannerMessage {
                    ListRefreshErrorBanner(
                        message: bannerMessage,
                        retryTitle: L10n.News.retryAction,
                        onRetry: { viewModel.onTrigger(.refresh) }
                    )
                }

                ForEach(articles) { article in
                    Button {
                        onArticleSelected(article.id)
                    } label: {
                        NewsCardView(article: article)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(Constants.AccessibilityID.articleCard)
                    .onAppear { viewModel.onTrigger(.articleAppeared(article.id)) }
                }

                ListLoadMoreFooter(
                    isLoadingMore: state.phase.isLoadingMore,
                    loadMoreError: state.pagination.loadMoreError,
                    retryTitle: L10n.News.retryAction,
                    onRetry: { viewModel.onTrigger(.retryLoadMore) }
                )
            }
            .padding(.horizontal, UIConstants.Padding.horizontal)
            .padding(.vertical, UIConstants.Padding.vertical)
        }
        .refreshable { await viewModel.refresh() }
    }
}

typealias DefaultNewsListView = NewsListView<NewsListViewModel>

// MARK: - Constants

private enum Constants {
    enum Icon {
        static let empty = "newspaper"
        static let noResults = "magnifyingglass"
    }

    enum AccessibilityID {
        static let articleCard = "articleCard"
    }
}

// MARK: - Previews

#Preview("Loaded") {
    NavigationStack {
        NewsListView(
            viewModel: StaticViewModel(state: NewsPreviewFixtures.listLoadedState),
            onArticleSelected: { _ in }
        )
    }
}

#Preview("Loading") {
    NavigationStack {
        NewsListView(
            viewModel: StaticViewModel(
                state: NewsListState(articles: [], searchText: "", pagination: .initial, phase: .loading(.initial))
            ),
            onArticleSelected: { _ in }
        )
    }
}

#Preview("Error") {
    NavigationStack {
        NewsListView(
            viewModel: StaticViewModel(
                state: NewsListState(
                    articles: [],
                    searchText: "",
                    pagination: .initial,
                    phase: .error(message: "Could not load news")
                )
            ),
            onArticleSelected: { _ in }
        )
    }
}

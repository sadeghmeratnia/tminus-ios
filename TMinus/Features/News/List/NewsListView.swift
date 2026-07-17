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
        return ListScreenScaffold(
            phase: phase,
            loadingTitle: L10n.News.loading,
            errorTitle: L10n.News.errorTitle,
            emptyTitle: L10n.News.emptyTitle,
            emptyDescription: L10n.News.emptyDescription,
            emptyIcon: Constants.Icon.empty
        ) {
            articlesListView(bannerMessage: refreshErrorMessage)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(L10n.News.navigationTitle)
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: searchBinding, prompt: L10n.News.searchPrompt)
        .task { viewModel.onTrigger(.onAppear) }
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
        .refreshable { viewModel.onTrigger(.refresh) }
    }
}

typealias DefaultNewsListView = NewsListView<NewsListViewModel>

// MARK: - Constants

private enum Constants {
    enum Icon {
        static let empty = "newspaper"
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

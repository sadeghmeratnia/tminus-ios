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

    private var contentPhase: ListContentPhase<NewsArticle> {
        .derive(phase: state.phase, items: articles)
    }

    private var refreshBannerMessage: String? {
        ListContentPhase.refreshErrorMessage(phase: state.phase, items: articles)
    }

    private var searchBinding: Binding<String> {
        Binding(
            get: { state.searchText },
            set: { viewModel.onTrigger(.searchTextChanged($0)) })
    }

    var body: some View {
        contentView
            .background(Color(.systemGroupedBackground))
            .navigationTitle(L10n.News.navigationTitle)
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: searchBinding, prompt: L10n.News.searchPrompt)
            .task { viewModel.onTrigger(.onAppear) }
    }

    private var contentView: some View {
        Group {
            switch contentPhase {
            case .loading:
                loadingView
            case let .error(message):
                errorView(message: message)
            case .empty:
                emptyView
            case .content:
                articlesListView(bannerMessage: refreshBannerMessage)
            }
        }
    }

    private var loadingView: some View {
        ProgressView(L10n.News.loading)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        ContentUnavailableView(
            L10n.News.errorTitle,
            systemImage: UIConstants.Icon.networkError,
            description: Text(message))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        ContentUnavailableView(
            L10n.News.emptyTitle,
            systemImage: Constants.Icon.empty,
            description: Text(L10n.News.emptyDescription))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func articlesListView(bannerMessage: String?) -> some View {
        ScrollView {
            LazyVStack(spacing: UIConstants.Spacing.large) {
                if let bannerMessage {
                    ListRefreshErrorBanner(
                        message: bannerMessage,
                        retryTitle: L10n.News.retryAction,
                        onRetry: { viewModel.onTrigger(.refresh) })
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

                if case .loading(.loadMore) = state.phase {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if let loadMoreError = state.pagination.loadMoreError {
                    ListLoadMoreErrorFooter(
                        message: loadMoreError,
                        retryTitle: L10n.News.retryAction,
                        onRetry: { viewModel.onTrigger(.retryLoadMore) })
                }
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
            onArticleSelected: { _ in })
    }
}

#Preview("Loading") {
    NavigationStack {
        NewsListView(
            viewModel: StaticViewModel(
                state: NewsListState(articles: [], searchText: "", pagination: .initial, phase: .loading(.initial))),
            onArticleSelected: { _ in })
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
                    phase: .error(message: "Could not load news"))),
            onArticleSelected: { _ in })
    }
}

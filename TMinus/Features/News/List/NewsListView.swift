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
                articlesListView
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
            systemImage: Constants.Icon.error,
            description: Text(message))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadMoreErrorFooter(message: String) -> some View {
        VStack(spacing: UIConstants.Spacing.small) {
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                viewModel.onTrigger(.retryLoadMore)
            } label: {
                Label(L10n.News.retryAction, systemImage: Constants.Icon.retry)
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, UIConstants.Padding.vertical)
    }

    private var emptyView: some View {
        ContentUnavailableView(
            L10n.News.emptyTitle,
            systemImage: Constants.Icon.empty,
            description: Text(L10n.News.emptyDescription))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var articlesListView: some View {
        ScrollView {
            LazyVStack(spacing: UIConstants.Spacing.large) {
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
                    loadMoreErrorFooter(message: loadMoreError)
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
        static let error = "wifi.exclamationmark"
        static let empty = "newspaper"
        static let retry = "arrow.clockwise"
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

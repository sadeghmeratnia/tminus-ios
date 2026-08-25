//
//  NewsListState.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import Foundation

// MARK: - NewsListState

struct NewsListState: Equatable, Sendable {
    let articles: [NewsArticle]
    let searchText: String
    let pagination: ListPagination
    let phase: ListPhase
    let loadGenerations: ListLoadGenerations

    init(articles: [NewsArticle],
         searchText: String,
         pagination: ListPagination,
         phase: ListPhase,
         loadGenerations: ListLoadGenerations = ListLoadGenerations())
    {
        self.articles = articles
        self.searchText = searchText
        self.pagination = pagination
        self.phase = phase
        self.loadGenerations = loadGenerations
    }

    static let initial = NewsListState(
        articles: [],
        searchText: "",
        pagination: .initial,
        phase: .idle
    )

    func with(articles: [NewsArticle]? = nil,
              searchText: String? = nil,
              pagination: ListPagination? = nil,
              phase: ListPhase? = nil,
              loadGenerations: ListLoadGenerations? = nil) -> NewsListState
    {
        NewsListState(
            articles: articles ?? self.articles,
            searchText: searchText ?? self.searchText,
            pagination: pagination ?? self.pagination,
            phase: phase ?? self.phase,
            loadGenerations: loadGenerations ?? self.loadGenerations
        )
    }

    /// See `LaunchListState`'s equivalent methods, same generation-guard rationale, shared via
    /// `ListLoadGenerations` rather than reimplemented per feature.
    func startingInitialLoad() -> (state: NewsListState, generation: Int) {
        let (next, value) = loadGenerations.advancing(for: .fresh)
        return (with(articles: [], pagination: .initial, phase: .loading(.initial), loadGenerations: next), value)
    }

    func startingRefresh() -> (state: NewsListState, generation: Int) {
        let (next, value) = loadGenerations.advancing(for: .fresh)
        return (
            with(pagination: pagination.clearingLoadMoreError(), phase: .loading(.refresh), loadGenerations: next),
            value
        )
    }

    func startingSearch(_ text: String) -> (state: NewsListState, generation: Int) {
        let (next, value) = loadGenerations.advancing(for: .fresh)
        return (
            with(articles: [], searchText: text, pagination: .initial, phase: .loading(.initial), loadGenerations: next),
            value
        )
    }

    /// See `LaunchListState`'s equivalent, also clears a stale `loadMoreError` so the load-more
    /// footer doesn't keep showing a pre-edit failure for the whole debounce window.
    func updatingSearchText(_ text: String) -> NewsListState {
        with(searchText: text, pagination: pagination.clearingLoadMoreError())
    }

    func startingLoadMore() -> (state: NewsListState, generation: Int) {
        let (next, value) = loadGenerations.advancing(for: .loadMore)
        return (
            with(pagination: pagination.clearingLoadMoreError(), phase: .loading(.loadMore), loadGenerations: next),
            value
        )
    }

    func applyingLoadResponse(searchText: String,
                              previousArticles: [NewsArticle],
                              page: PagedResult<NewsArticle>,
                              kind: ListLoadKind,
                              errorPresentation: LoadPresentationKind,
                              errorMessage: String?,
                              generation: Int) -> NewsListState
    {
        guard searchText == self.searchText, loadGenerations.matches(generation, for: kind) else { return self }

        if let errorMessage {
            if kind == .loadMore {
                return with(
                    articles: previousArticles,
                    pagination: pagination.failingLoadMore(message: errorMessage),
                    phase: .loaded
                )
            }

            // See `LaunchListState`'s equivalent, enforced here rather than trusted from the
            // caller's `previousArticles`.
            let articlesOnError = errorPresentation == .initial ? [] : previousArticles
            return with(
                articles: articlesOnError,
                pagination: pagination.clearingLoadMoreError(),
                phase: .error(message: errorMessage)
            )
        }

        let articles = kind == .loadMore ? previousArticles.merging(page.items) : page.items
        return with(
            articles: articles,
            pagination: pagination.applying(page: page),
            phase: .loaded
        )
    }
}

// MARK: - NewsListTrigger

enum NewsListTrigger: Sendable {
    case onAppear
    case refresh
    case retry
    case searchTextChanged(String)
    case articleAppeared(String)
    case retryLoadMore
}

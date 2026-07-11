//
//  NewsListState.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import Foundation

// MARK: - NewsListState

struct NewsListState: Equatable {
    let articles: [NewsArticle]
    let searchText: String
    let pagination: ListPagination
    let phase: ListPhase

    static let initial = NewsListState(
        articles: [],
        searchText: "",
        pagination: .initial,
        phase: .idle)

    func with(articles: [NewsArticle]? = nil,
              searchText: String? = nil,
              pagination: ListPagination? = nil,
              phase: ListPhase? = nil) -> NewsListState {
        NewsListState(
            articles: articles ?? self.articles,
            searchText: searchText ?? self.searchText,
            pagination: pagination ?? self.pagination,
            phase: phase ?? self.phase)
    }

    func startingInitialLoad() -> NewsListState {
        with(articles: [], pagination: .initial, phase: .loading(.initial))
    }

    func startingRefresh() -> NewsListState {
        with(phase: .loading(.refresh))
    }

    func startingSearch(_ text: String) -> NewsListState {
        with(articles: [], searchText: text, pagination: .initial, phase: .loading(.initial))
    }

    func updatingSearchText(_ text: String) -> NewsListState {
        with(searchText: text)
    }

    func startingLoadMore() -> NewsListState {
        with(pagination: pagination.clearingLoadMoreError(), phase: .loading(.loadMore))
    }

    func applyingLoadResponse(searchText: String,
                              previousArticles: [NewsArticle],
                              page: PagedResult<NewsArticle>,
                              kind: ListLoadKind,
                              errorMessage: String?) -> NewsListState {
        guard searchText == self.searchText else { return self }

        if let errorMessage {
            if kind == .loadMore {
                return with(
                    articles: previousArticles,
                    pagination: pagination.failingLoadMore(message: errorMessage),
                    phase: .loaded)
            }

            return with(
                articles: previousArticles,
                pagination: pagination.clearingLoadMoreError(),
                phase: .error(message: errorMessage))
        }

        let articles = kind == .loadMore ? previousArticles.merging(page.items) : page.items
        return with(
            articles: articles,
            pagination: pagination.applying(page: page),
            phase: .loaded)
    }
}

// MARK: - NewsListTrigger

enum NewsListTrigger {
    case onAppear
    case refresh
    case searchTextChanged(String)
    case articleAppeared(String)
    case retryLoadMore
}

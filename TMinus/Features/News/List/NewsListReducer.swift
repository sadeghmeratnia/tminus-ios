//
//  NewsListReducer.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import Foundation

// MARK: - NewsListAction

enum NewsListAction {
    case appear
    case refresh
    case searchTextChanged(String)
    case search(String)
    case loadMore
    case retryLoadMore
    case loadResponse(
        searchText: String,
        previousArticles: [NewsArticle],
        page: PagedResult<NewsArticle>,
        kind: ListLoadKind,
        errorMessage: String?)
}

// MARK: - NewsListEffect

enum NewsListEffect {
    case load(
        searchText: String,
        page: Int,
        previousArticles: [NewsArticle],
        fetchPolicy: FetchPolicy,
        kind: ListLoadKind)
}

// MARK: - NewsListReducer

enum NewsListReducer {
    static func reduce(state: NewsListState,
                       action: NewsListAction) -> (state: NewsListState, effect: NewsListEffect?) {
        switch action {
        case .appear:
            return (
                state.startingInitialLoad(),
                loadEffect(searchText: state.searchText, page: 1, previousArticles: [], fetchPolicy: .useCache, kind: .fresh))

        case .refresh:
            return (
                state.startingRefresh(),
                loadEffect(
                    searchText: state.searchText,
                    page: 1,
                    previousArticles: state.articles,
                    fetchPolicy: .networkOnly,
                    kind: .fresh))

        case let .searchTextChanged(text):
            return (state.updatingSearchText(text), nil)

        case let .search(text):
            return (
                state.startingSearch(text),
                loadEffect(searchText: text, page: 1, previousArticles: [], fetchPolicy: .useCache, kind: .fresh))

        case .retryLoadMore:
            guard state.pagination.loadMoreError != nil,
                  let nextPage = state.pagination.nextPage else {
                return (state, nil)
            }
            return (
                state.startingLoadMore(),
                loadEffect(
                    searchText: state.searchText,
                    page: nextPage,
                    previousArticles: state.articles,
                    fetchPolicy: .networkOnly,
                    kind: .loadMore))

        case .loadMore:
            guard case .loaded = state.phase,
                  state.pagination.loadMoreError == nil,
                  let nextPage = state.pagination.nextPage,
                  state.articles.isEmpty == false else {
                return (state, nil)
            }
            return (
                state.startingLoadMore(),
                loadEffect(
                    searchText: state.searchText,
                    page: nextPage,
                    previousArticles: state.articles,
                    fetchPolicy: .networkOnly,
                    kind: .loadMore))

        case let .loadResponse(searchText, previousArticles, page, kind, errorMessage):
            return (
                state.applyingLoadResponse(
                    searchText: searchText,
                    previousArticles: previousArticles,
                    page: page,
                    kind: kind,
                    errorMessage: errorMessage),
                nil)
        }
    }

    private static func loadEffect(searchText: String,
                                   page: Int,
                                   previousArticles: [NewsArticle],
                                   fetchPolicy: FetchPolicy,
                                   kind: ListLoadKind) -> NewsListEffect {
        .load(searchText: searchText, page: page, previousArticles: previousArticles, fetchPolicy: fetchPolicy, kind: kind)
    }
}

// MARK: ReducerProtocol

extension NewsListReducer: ReducerProtocol { }

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
        errorMessage: String?,
        generation: Int)
}

// MARK: - NewsListEffect

enum NewsListEffect {
    case load(
        searchText: String,
        page: Int,
        previousArticles: [NewsArticle],
        fetchPolicy: FetchPolicy,
        kind: ListLoadKind,
        generation: Int)
}

// MARK: - NewsListReducer

enum NewsListReducer {
    static func reduce(state: NewsListState,
                       action: NewsListAction) -> (state: NewsListState, effect: NewsListEffect?) {
        switch action {
        case .appear:
            let (nextState, generation) = state.startingInitialLoad()
            return (
                nextState,
                loadEffect(
                    searchText: state.searchText,
                    page: 1,
                    previousArticles: [],
                    fetchPolicy: .useCache,
                    kind: .fresh,
                    generation: generation))

        case .refresh:
            let (nextState, generation) = state.startingRefresh()
            return (
                nextState,
                loadEffect(
                    searchText: state.searchText,
                    page: 1,
                    previousArticles: state.articles,
                    fetchPolicy: .networkOnly,
                    kind: .fresh,
                    generation: generation))

        case let .searchTextChanged(text):
            return (state.updatingSearchText(text), nil)

        case let .search(text):
            let (nextState, generation) = state.startingSearch(text)
            return (
                nextState,
                loadEffect(
                    searchText: text,
                    page: 1,
                    previousArticles: [],
                    fetchPolicy: .useCache,
                    kind: .fresh,
                    generation: generation))

        case .retryLoadMore:
            guard state.pagination.loadMoreError != nil,
                  let nextPage = state.pagination.nextPage else {
                return (state, nil)
            }
            let (nextState, generation) = state.startingLoadMore()
            return (
                nextState,
                loadEffect(
                    searchText: state.searchText,
                    page: nextPage,
                    previousArticles: state.articles,
                    fetchPolicy: .networkOnly,
                    kind: .loadMore,
                    generation: generation))

        case .loadMore:
            guard case .loaded = state.phase,
                  state.pagination.loadMoreError == nil,
                  let nextPage = state.pagination.nextPage,
                  state.articles.isEmpty == false else {
                return (state, nil)
            }
            let (nextState, generation) = state.startingLoadMore()
            return (
                nextState,
                loadEffect(
                    searchText: state.searchText,
                    page: nextPage,
                    previousArticles: state.articles,
                    fetchPolicy: .networkOnly,
                    kind: .loadMore,
                    generation: generation))

        case let .loadResponse(searchText, previousArticles, page, kind, errorMessage, generation):
            return (
                state.applyingLoadResponse(
                    searchText: searchText,
                    previousArticles: previousArticles,
                    page: page,
                    kind: kind,
                    errorMessage: errorMessage,
                    generation: generation),
                nil)
        }
    }

    private static func loadEffect(searchText: String,
                                   page: Int,
                                   previousArticles: [NewsArticle],
                                   fetchPolicy: FetchPolicy,
                                   kind: ListLoadKind,
                                   generation: Int) -> NewsListEffect {
        .load(
            searchText: searchText,
            page: page,
            previousArticles: previousArticles,
            fetchPolicy: fetchPolicy,
            kind: kind,
            generation: generation)
    }
}

// MARK: ReducerProtocol

extension NewsListReducer: ReducerProtocol { }

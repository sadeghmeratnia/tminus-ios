//
//  NewsListReducer.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import Foundation

// MARK: - NewsListAction

enum NewsListAction: Sendable {
    case appear
    case refresh
    case retry
    case searchTextChanged(String)
    case search(String)
    case loadMore
    case retryLoadMore
    case loadResponse(
        searchText: String,
        previousArticles: [NewsArticle],
        page: PagedResult<NewsArticle>,
        kind: ListLoadKind,
        errorPresentation: LoadPresentationKind,
        errorMessage: String?,
        generation: Int
    )
    /// See `LaunchListAction.cancelled`, sent when the ViewModel cancels in-flight work rather
    /// than a load ever resolving, so `phase` doesn't get stuck at whatever `.loading` case
    /// started it.
    case cancelled
}

// MARK: - NewsListEffect

enum NewsListEffect: Sendable {
    case load(
        searchText: String,
        page: Int,
        previousArticles: [NewsArticle],
        fetchPolicy: FetchPolicy,
        kind: ListLoadKind,
        errorPresentation: LoadPresentationKind,
        generation: Int
    )
}

// MARK: - NewsListReducer

enum NewsListReducer {
    static func reduce(state: NewsListState,
                       action: NewsListAction) -> (state: NewsListState, effect: NewsListEffect?)
    {
        switch action {
        case .appear:
            // Defense in depth, mirroring `LaunchListReducer.appear`, today the ViewModel's
            // `hasAppeared` flag is the only thing preventing a second `.appear` from wiping a
            // fully-loaded list back to `.loading(.initial)`; guarding on phase here makes that
            // idempotency a property of the reducer itself, not just of one call site.
            guard case .idle = state.phase else {
                return (state, nil)
            }
            let (nextState, generation) = state.startingInitialLoad()
            return (
                nextState,
                loadEffect(
                    searchText: state.searchText,
                    page: 1,
                    previousArticles: [],
                    fetchPolicy: .useCache,
                    kind: .fresh,
                    errorPresentation: .initial,
                    generation: generation
                )
            )

        case .retry:
            // See `LaunchListReducer`'s equivalent, meaningful from the full-screen error state
            // OR a genuinely-empty loaded state (e.g. a zero-result search), since
            // `ListScreenScaffold` surfaces the same retry button on both `.error` and `.empty`.
            guard state.articles.isEmpty else {
                return (state, nil)
            }
            switch state.phase {
            case .error, .loaded:
                break
            case .idle, .loading:
                return (state, nil)
            }
            let (nextState, generation) = state.startingInitialLoad()
            return (
                nextState,
                loadEffect(
                    searchText: state.searchText,
                    page: 1,
                    previousArticles: [],
                    fetchPolicy: .useCache,
                    kind: .fresh,
                    errorPresentation: .initial,
                    generation: generation
                )
            )

        case .refresh:
            // See `LaunchListReducer`'s equivalent, only meaningful once there's content to
            // refresh, and excludes an already-in-flight refresh so a second pull-to-refresh
            // can't start an overlapping load.
            guard state.articles.isEmpty == false, state.phase != .loading(.refresh) else {
                return (state, nil)
            }
            let (nextState, generation) = state.startingRefresh()
            return (
                nextState,
                loadEffect(
                    searchText: state.searchText,
                    page: 1,
                    previousArticles: state.articles,
                    fetchPolicy: .networkOnly,
                    kind: .fresh,
                    errorPresentation: .refresh,
                    generation: generation
                )
            )

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
                    errorPresentation: .initial,
                    generation: generation
                )
            )

        case .retryLoadMore:
            guard case .loaded = state.phase,
                  let nextPage = state.pagination.retryLoadMorePage
            else {
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
                    errorPresentation: .refresh,
                    generation: generation
                )
            )

        case .loadMore:
            guard case .loaded = state.phase,
                  state.pagination.loadMoreError == nil,
                  let nextPage = state.pagination.nextPage,
                  state.articles.isEmpty == false
            else {
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
                    errorPresentation: .refresh,
                    generation: generation
                )
            )

        case let .loadResponse(searchText, previousArticles, page, kind, errorPresentation, errorMessage, generation):
            return (
                state.applyingLoadResponse(
                    searchText: searchText,
                    previousArticles: previousArticles,
                    page: page,
                    kind: kind,
                    errorPresentation: errorPresentation,
                    errorMessage: errorMessage,
                    generation: generation
                ),
                nil
            )

        case .cancelled:
            switch state.phase {
            case .loading(.initial), .loading(.refresh):
                // Also advances the `.fresh` generation, see `LaunchListReducer.cancelled` for
                // why: a task that doesn't observe cancellation in time (e.g. coalesced onto
                // another caller's in-flight `.useCache` fetch) can still call
                // `send(.loadResponse(...))` later, and without bumping the generation here that
                // response would pass `applyingLoadResponse`'s guard and resurrect stale state
                // after this reducer already moved on.
                let (nextGenerations, _) = state.loadGenerations.advancing(for: .fresh)
                let phase: ListPhase = state.phase == .loading(.initial) ? .idle : .loaded
                return (state.with(phase: phase, loadGenerations: nextGenerations), nil)
            case .loading(.loadMore):
                let (nextGenerations, _) = state.loadGenerations.advancing(for: .loadMore)
                return (state.with(phase: .loaded, loadGenerations: nextGenerations), nil)
            case .idle, .loaded, .error:
                return (state, nil)
            }
        }
    }

    private static func loadEffect(searchText: String,
                                   page: Int,
                                   previousArticles: [NewsArticle],
                                   fetchPolicy: FetchPolicy,
                                   kind: ListLoadKind,
                                   errorPresentation: LoadPresentationKind,
                                   generation: Int) -> NewsListEffect
    {
        .load(
            searchText: searchText,
            page: page,
            previousArticles: previousArticles,
            fetchPolicy: fetchPolicy,
            kind: kind,
            errorPresentation: errorPresentation,
            generation: generation
        )
    }
}

// MARK: ReducerProtocol

extension NewsListReducer: ReducerProtocol {}

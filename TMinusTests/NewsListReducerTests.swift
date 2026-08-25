//
//  NewsListReducerTests.swift
//  TMinusTests
//
//  Created by Sadegh on 09/07/2026.
//

import Foundation
import Testing
@testable import TMinus

@Suite("NewsListReducer")
enum NewsListReducerTests {
    @Test("Appear loads using cache with the current search text")
    static func appearLoadsCurrentSearch() {
        let state = NewsListState(articles: [], searchText: "starship", pagination: .initial, phase: .idle)

        let result = NewsListReducer.reduce(state: state, action: .appear)

        #expect(result.state.phase == .loading(.initial))
        guard case let .load(searchText, page, previousArticles, fetchPolicy, kind, errorPresentation, _) = result.effect else {
            Issue.record("Expected load effect")
            return
        }
        #expect(searchText == "starship")
        #expect(page == 1)
        #expect(previousArticles.isEmpty)
        #expect(fetchPolicy == .useCache)
        #expect(kind == .fresh)
        #expect(errorPresentation == .initial)
    }

    @Test("A second appear is a no-op once loading has started")
    static func appearIsANoOpOutsideIdleState() {
        let state = NewsListState(articles: [], searchText: "", pagination: .initial, phase: .loading(.initial))

        let result = NewsListReducer.reduce(state: state, action: .appear)

        #expect(result.effect == nil)
        #expect(result.state == state)
    }

    @Test("searchTextChanged updates text without loading")
    static func searchTextChangedUpdatesTextOnly() {
        let state = NewsListState(articles: [makeArticle(id: "1")], searchText: "", pagination: .initial, phase: .loaded)

        let result = NewsListReducer.reduce(state: state, action: .searchTextChanged("moon"))

        #expect(result.state.searchText == "moon")
        #expect(result.state.articles.count == 1)
        #expect(result.state.phase == .loaded)
        #expect(result.effect == nil)
    }

    @Test("searchTextChanged clears a stale load-more error")
    static func searchTextChangedClearsStaleLoadMoreError() {
        let state = NewsListState(
            articles: [makeArticle(id: "1")],
            searchText: "",
            pagination: .initial.failingLoadMore(message: "failed"),
            phase: .loaded
        )

        let result = NewsListReducer.reduce(state: state, action: .searchTextChanged("moon"))

        #expect(result.state.pagination.loadMoreError == nil)
    }

    @Test("search starts a fresh load for the debounced text")
    static func searchStartsFreshLoad() {
        let state = NewsListState(articles: [makeArticle(id: "1")], searchText: "moon", pagination: .initial, phase: .loaded)

        let result = NewsListReducer.reduce(state: state, action: .search("moon"))

        #expect(result.state.articles.isEmpty)
        #expect(result.state.phase == .loading(.initial))
        guard case let .load(searchText, page, previousArticles, fetchPolicy, kind, errorPresentation, _) = result.effect else {
            Issue.record("Expected load effect")
            return
        }
        #expect(searchText == "moon")
        #expect(page == 1)
        #expect(previousArticles.isEmpty)
        #expect(fetchPolicy == .useCache)
        #expect(kind == .fresh)
        #expect(errorPresentation == .initial)
    }

    @Test("A response for a superseded search is dropped")
    static func staleSearchResponseIsDropped() {
        let state = NewsListState(articles: [], searchText: "moon", pagination: .initial, phase: .loading(.initial))

        let result = NewsListReducer.reduce(
            state: state,
            action: .loadResponse(
                searchText: "mars",
                previousArticles: [],
                page: PagedResult(items: [makeArticle(id: "stale")], currentPage: 1),
                kind: .fresh,
                errorPresentation: .initial,
                errorMessage: nil,
                generation: 0
            )
        )

        #expect(result.state.articles.isEmpty)
        #expect(result.state == state)
    }

    @Test("A response matching the current search is applied")
    static func matchingSearchResponseIsApplied() {
        let state = NewsListState(articles: [], searchText: "moon", pagination: .initial, phase: .loading(.initial))

        let result = NewsListReducer.reduce(
            state: state,
            action: .loadResponse(
                searchText: "moon",
                previousArticles: [],
                page: PagedResult(items: [makeArticle(id: "1")], currentPage: 1),
                kind: .fresh,
                errorPresentation: .initial,
                errorMessage: nil,
                generation: 0
            )
        )

        #expect(result.state.articles.map(\.id) == ["1"])
        #expect(result.state.phase == .loaded)
    }

    @Test("Load more requests next page with network-only policy")
    static func loadMoreRequestsNextPage() {
        let articles = [makeArticle(id: "1")]
        let pagination = ListPagination(currentPage: 1, nextPage: 2, previousPage: nil, totalCount: 100, loadMoreError: nil)
        let state = NewsListState(articles: articles, searchText: "", pagination: pagination, phase: .loaded)

        let result = NewsListReducer.reduce(state: state, action: .loadMore)

        guard case let .load(searchText, page, previousArticles, fetchPolicy, kind, _, _) = result.effect else {
            Issue.record("Expected load-more effect")
            return
        }
        #expect(searchText == "")
        #expect(page == 2)
        #expect(previousArticles == articles)
        #expect(fetchPolicy == .networkOnly)
        #expect(kind == .loadMore)
        #expect(result.state.phase == .loading(.loadMore))
    }

    @Test("Load more is blocked while a load-more error is present")
    static func loadMoreBlockedByError() {
        let articles = [makeArticle(id: "1")]
        let pagination = ListPagination(currentPage: 1, nextPage: 2, previousPage: nil, totalCount: 100, loadMoreError: "failed")
        let state = NewsListState(articles: articles, searchText: "", pagination: pagination, phase: .loaded)

        let result = NewsListReducer.reduce(state: state, action: .loadMore)

        #expect(result.effect == nil)
    }

    @Test("Retry load more clears error and triggers load")
    static func retryLoadMoreClearsErrorAndLoads() {
        let articles = [makeArticle(id: "1")]
        let pagination = ListPagination(currentPage: 1, nextPage: 2, previousPage: nil, totalCount: 100, loadMoreError: "failed")
        let state = NewsListState(articles: articles, searchText: "", pagination: pagination, phase: .loaded)

        let result = NewsListReducer.reduce(state: state, action: .retryLoadMore)

        guard case let .load(_, page, previousArticles, fetchPolicy, kind, _, _) = result.effect else {
            Issue.record("Expected load effect from retry")
            return
        }
        #expect(page == 2)
        #expect(previousArticles == articles)
        #expect(fetchPolicy == .networkOnly)
        #expect(kind == .loadMore)
        #expect(result.state.pagination.loadMoreError == nil)
    }

    @Test("A response for a superseded generation with matching search text is dropped")
    static func staleGenerationResponseIsDropped() {
        // Two overlapping refreshes (e.g. rapid pull-to-refresh) share the same search text, so
        // only the generation guard, not the existing searchText check, can tell them apart.
        // The reducer's own `.refresh` guard now blocks a second refresh while one is in flight,
        // so this drives the state transition directly via `startingRefresh()` (the same call
        // the reducer itself makes) to exercise the generation guard in isolation.
        let loadedState = NewsListState(
            articles: [makeArticle(id: "existing")],
            searchText: "",
            pagination: .initial,
            phase: .loaded
        )
        let (firstRefreshState, _) = loadedState.startingRefresh()
        let (secondRefreshState, _) = firstRefreshState.startingRefresh()

        let staleResult = NewsListReducer.reduce(
            state: secondRefreshState,
            action: .loadResponse(
                searchText: "",
                previousArticles: [],
                page: PagedResult(items: [makeArticle(id: "stale")], currentPage: 1),
                kind: .fresh,
                errorPresentation: .refresh,
                errorMessage: nil,
                generation: 1
            )
        )

        #expect(staleResult.state == secondRefreshState)

        let currentResult = NewsListReducer.reduce(
            state: secondRefreshState,
            action: .loadResponse(
                searchText: "",
                previousArticles: [],
                page: PagedResult(items: [makeArticle(id: "current")], currentPage: 1),
                kind: .fresh,
                errorPresentation: .refresh,
                errorMessage: nil,
                generation: 2
            )
        )

        #expect(currentResult.state.articles.map(\.id) == ["current"])
    }

    @Test("Refresh is a no-op when there is nothing on screen to refresh")
    static func refreshIsANoOpWhenEmpty() {
        let state = NewsListState(articles: [], searchText: "", pagination: .initial, phase: .idle)

        let result = NewsListReducer.reduce(state: state, action: .refresh)

        #expect(result.effect == nil)
        #expect(result.state == state)
    }

    @Test("Refresh is a no-op while a refresh is already in flight")
    static func refreshIsANoOpWhileAlreadyRefreshing() {
        let state = NewsListState(
            articles: [makeArticle(id: "existing")],
            searchText: "",
            pagination: .initial,
            phase: .loading(.refresh)
        )

        let result = NewsListReducer.reduce(state: state, action: .refresh)

        #expect(result.effect == nil)
        #expect(result.state == state)
    }

    @Test("Retry is a no-op unless the screen is in a blank error state")
    static func retryIsANoOpOutsideBlankErrorState() {
        let state = NewsListState(articles: [], searchText: "", pagination: .initial, phase: .idle)

        let result = NewsListReducer.reduce(state: state, action: .retry)

        #expect(result.effect == nil)
        #expect(result.state == state)
    }

    @Test("Retry restarts an initial load from the blank error state")
    static func retryRestartsInitialLoad() {
        let state = NewsListState(articles: [], searchText: "", pagination: .initial, phase: .error(message: "failed"))

        let result = NewsListReducer.reduce(state: state, action: .retry)

        #expect(result.state.phase == .loading(.initial))
        guard case let .load(_, _, _, fetchPolicy, kind, errorPresentation, _) = result.effect else {
            Issue.record("Expected load effect from retry")
            return
        }
        #expect(fetchPolicy == .useCache)
        #expect(kind == .fresh)
        #expect(errorPresentation == .initial)
    }

    // See `LaunchListReducerTests.retryRestartsInitialLoadFromEmptyLoadedState`, mirrors the
    // same fix for News: `ListScreenScaffold` surfaces retry on `.empty` too, which covers
    // `.loaded` with no articles (e.g. a zero-result search), not just `.error`.
    @Test("Retry restarts an initial load from a genuinely-empty loaded state")
    static func retryRestartsInitialLoadFromEmptyLoadedState() {
        let state = NewsListState(articles: [], searchText: "no matches", pagination: .initial, phase: .loaded)

        let result = NewsListReducer.reduce(state: state, action: .retry)

        #expect(result.state.phase == .loading(.initial))
        guard case let .load(searchText, _, _, fetchPolicy, kind, errorPresentation, _) = result.effect else {
            Issue.record("Expected load effect from retry")
            return
        }
        #expect(searchText == "no matches")
        #expect(fetchPolicy == .useCache)
        #expect(kind == .fresh)
        #expect(errorPresentation == .initial)
    }

    @Test("Retry is still a no-op from a loaded state that has items")
    static func retryIsANoOpFromNonEmptyLoadedState() {
        let state = NewsListState(articles: [makeArticle(id: "1")], searchText: "", pagination: .initial, phase: .loaded)

        let result = NewsListReducer.reduce(state: state, action: .retry)

        #expect(result.effect == nil)
        #expect(result.state == state)
    }

    @Test("A failed refresh preserves existing articles instead of blanking the screen")
    static func failedRefreshPreservesArticles() {
        let articles = [makeArticle(id: "existing")]
        let state = NewsListState(articles: articles, searchText: "", pagination: .initial, phase: .loaded)
        let refreshed = NewsListReducer.reduce(state: state, action: .refresh)

        guard case let .load(_, _, _, _, _, _, generation) = refreshed.effect else {
            Issue.record("Expected load effect from refresh")
            return
        }

        let result = NewsListReducer.reduce(
            state: refreshed.state,
            action: .loadResponse(
                searchText: "",
                previousArticles: articles,
                page: PagedResult(items: []),
                kind: .fresh,
                errorPresentation: .refresh,
                errorMessage: "network error",
                generation: generation
            )
        )

        #expect(result.state.articles == articles)
        if case let .error(message) = result.state.phase {
            #expect(message == "network error")
        } else {
            Issue.record("Expected error phase")
        }
    }

    @Test("Cancelling an in-flight initial load reverts to idle so a future appear can restart it")
    static func cancellingInitialLoadRevertsToIdle() {
        let state = NewsListState(articles: [], searchText: "", pagination: .initial, phase: .loading(.initial))

        let result = NewsListReducer.reduce(state: state, action: .cancelled)

        #expect(result.state.phase == .idle)
        #expect(result.effect == nil)
    }

    // See `LaunchListReducerTests`'s equivalent, a task that doesn't observe cancellation in
    // time can still resolve after `cancelInFlightWork()` already reverted `phase`, and without
    // `.cancelled` also bumping the generation that late response would resurrect stale state.
    @Test("Cancelling an in-flight load invalidates its generation, so a late response is dropped")
    static func cancellingInvalidatesGenerationForLateResponse() {
        let (loadingState, generation) = NewsListState(
            articles: [], searchText: "", pagination: .initial, phase: .idle
        ).startingInitialLoad()

        let cancelledState = NewsListReducer.reduce(state: loadingState, action: .cancelled).state
        #expect(cancelledState.phase == .idle)

        let lateResponseResult = NewsListReducer.reduce(
            state: cancelledState,
            action: .loadResponse(
                searchText: "",
                previousArticles: [],
                page: PagedResult(items: [makeArticle(id: "late")], currentPage: 1),
                kind: .fresh,
                errorPresentation: .initial,
                errorMessage: nil,
                generation: generation
            )
        )

        #expect(lateResponseResult.state == cancelledState)
    }

    @Test("Cancelling an in-flight refresh or load-more falls back to loaded, keeping existing items")
    static func cancellingRefreshOrLoadMoreRevertsToLoaded() {
        let articles = [makeArticle(id: "existing")]

        let refreshResult = NewsListReducer.reduce(
            state: NewsListState(articles: articles, searchText: "", pagination: .initial, phase: .loading(.refresh)),
            action: .cancelled
        )
        #expect(refreshResult.state.phase == .loaded)
        #expect(refreshResult.state.articles == articles)

        let loadMoreResult = NewsListReducer.reduce(
            state: NewsListState(articles: articles, searchText: "", pagination: .initial, phase: .loading(.loadMore)),
            action: .cancelled
        )
        #expect(loadMoreResult.state.phase == .loaded)
        #expect(loadMoreResult.state.articles == articles)
    }

    @Test("Cancelling is a no-op outside a loading phase")
    static func cancellingIsANoOpOutsideLoadingPhase() {
        let idleState = NewsListState(articles: [], searchText: "", pagination: .initial, phase: .idle)
        #expect(NewsListReducer.reduce(state: idleState, action: .cancelled).state == idleState)

        let loadedState = NewsListState(articles: [makeArticle(id: "1")], searchText: "", pagination: .initial, phase: .loaded)
        #expect(NewsListReducer.reduce(state: loadedState, action: .cancelled).state == loadedState)

        let errorState = NewsListState(articles: [], searchText: "", pagination: .initial, phase: .error(message: "failed"))
        #expect(NewsListReducer.reduce(state: errorState, action: .cancelled).state == errorState)
    }
}

private extension NewsListReducerTests {
    static func makeArticle(id: String) -> NewsArticle {
        NewsArticle(
            id: id,
            title: "Article \(id)",
            summary: "Summary",
            url: URL(string: "https://example.com/\(id)")!,
            imageURL: nil,
            newsSite: "SpaceNews",
            publishedAt: Date(timeIntervalSince1970: 1000),
            relatedLaunchIDs: []
        )
    }
}

//
//  LaunchListReducerTests.swift
//  TMinusTests
//
//  Created by Sadegh on 12/05/2026.
//

import Foundation
import Testing
@testable import TMinus

// MARK: - LaunchListReducerTests

@Suite("LaunchListReducer")
enum LaunchListReducerTests {
    @Test("Appear loads current mode and search text using cache")
    static func appearLoadsCurrentMode() {
        let state = LaunchListState(mode: .upcoming, launches: [], searchText: "starship", pagination: .initial, phase: .idle)

        let result = LaunchListReducer.reduce(state: state, action: .appear)

        #expect(result.state.mode == .upcoming)
        #expect(result.state.launches.isEmpty)
        #expect(result.state.phase == .loading(.initial))
        guard case let .load(mode, searchText, page, previousLaunches, fetchPolicy, kind, errorPresentation, _) = result.effect else {
            Issue.record("Expected load effect")
            return
        }
        #expect(mode == .upcoming)
        #expect(searchText == "starship")
        #expect(page == 1)
        #expect(previousLaunches.isEmpty)
        #expect(fetchPolicy == .useCache)
        #expect(kind == .fresh)
        #expect(errorPresentation == .initial)
    }

    @Test("Refresh keeps previous launches, search text, and reloads ignoring cache")
    static func refreshKeepsPreviousLaunches() {
        let previousLaunches = [makeLaunch(id: "1"), makeLaunch(id: "2")]
        let state = LaunchListState(
            mode: .previous,
            launches: previousLaunches,
            searchText: "falcon",
            pagination: .initial,
            phase: .loaded
        )

        let result = LaunchListReducer.reduce(state: state, action: .refresh)

        #expect(result.state.mode == .previous)
        #expect(result.state.launches == previousLaunches)
        #expect(result.state.phase == .loading(.refresh))
        guard case let .load(mode, searchText, page, launches, fetchPolicy, kind, errorPresentation, _) = result.effect else {
            Issue.record("Expected load effect")
            return
        }
        #expect(mode == .previous)
        #expect(searchText == "falcon")
        #expect(page == 1)
        #expect(launches == previousLaunches)
        #expect(fetchPolicy == .networkOnly)
        #expect(kind == .fresh)
        #expect(errorPresentation == .refresh)
    }

    @Test("Refresh is a no-op when there is nothing on screen to refresh")
    static func refreshIsANoOpWhenEmpty() {
        let state = LaunchListState(mode: .upcoming, launches: [], pagination: .initial, phase: .idle)

        let result = LaunchListReducer.reduce(state: state, action: .refresh)

        #expect(result.effect == nil)
        #expect(result.state == state)
    }

    @Test("Refresh is a no-op while a refresh is already in flight")
    static func refreshIsANoOpWhileAlreadyRefreshing() {
        let state = LaunchListState(
            mode: .upcoming,
            launches: [makeLaunch(id: "existing")],
            pagination: .initial,
            phase: .loading(.refresh)
        )

        let result = LaunchListReducer.reduce(state: state, action: .refresh)

        #expect(result.effect == nil)
        #expect(result.state == state)
    }

    @Test("Retry is a no-op unless the screen is in a blank error state")
    static func retryIsANoOpOutsideBlankErrorState() {
        let idleState = LaunchListState(mode: .upcoming, launches: [], pagination: .initial, phase: .idle)
        #expect(LaunchListReducer.reduce(state: idleState, action: .retry).effect == nil)

        let bannerErrorState = LaunchListState(
            mode: .upcoming,
            launches: [makeLaunch(id: "1")],
            pagination: .initial,
            phase: .error(message: "failed")
        )
        #expect(LaunchListReducer.reduce(state: bannerErrorState, action: .retry).effect == nil)
    }

    @Test("Retry restarts an initial load from the blank error state")
    static func retryRestartsInitialLoad() {
        let state = LaunchListState(mode: .upcoming, launches: [], pagination: .initial, phase: .error(message: "failed"))

        let result = LaunchListReducer.reduce(state: state, action: .retry)

        #expect(result.state.phase == .loading(.initial))
        guard case let .load(_, _, _, _, fetchPolicy, kind, errorPresentation, _) = result.effect else {
            Issue.record("Expected load effect from retry")
            return
        }
        #expect(fetchPolicy == .useCache)
        #expect(kind == .fresh)
        #expect(errorPresentation == .initial)
    }

    // `ListScreenScaffold` surfaces the same retry button on `.empty` as on `.error` (see its
    // doc comment), and `ListContentPhase.derive` maps `(phase: .loaded, items: [])` to `.empty`
    //, a genuine zero-result search or empty list. Without this, `.retry` was a silent no-op
    // from that exact state, leaving a visible, tappable button that did nothing.
    @Test("Retry restarts an initial load from a genuinely-empty loaded state")
    static func retryRestartsInitialLoadFromEmptyLoadedState() {
        let state = LaunchListState(mode: .upcoming, launches: [], searchText: "no matches", pagination: .initial, phase: .loaded)

        let result = LaunchListReducer.reduce(state: state, action: .retry)

        #expect(result.state.phase == .loading(.initial))
        guard case let .load(_, searchText, _, _, fetchPolicy, kind, errorPresentation, _) = result.effect else {
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
        let state = LaunchListState(mode: .upcoming, launches: [makeLaunch(id: "1")], pagination: .initial, phase: .loaded)

        let result = LaunchListReducer.reduce(state: state, action: .retry)

        #expect(result.effect == nil)
        #expect(result.state == state)
    }

    @Test("Mode change to same mode has no effect")
    static func modeChangedToSameModeNoEffect() {
        let launches = [makeLaunch(id: "x")]
        let state = LaunchListState(mode: .upcoming, launches: launches, pagination: .initial, phase: .loaded)

        let result = LaunchListReducer.reduce(state: state, action: .modeChanged(.upcoming))

        #expect(result.state.mode == .upcoming)
        #expect(result.state.launches == launches)
        #expect(result.effect == nil)
    }

    @Test("Mode change to a different mode keeps the active search text")
    static func modeChangedKeepsSearchText() {
        let state = LaunchListState(mode: .upcoming, launches: [makeLaunch(id: "x")], searchText: "falcon", pagination: .initial, phase: .loaded)

        let result = LaunchListReducer.reduce(state: state, action: .modeChanged(.previous))

        #expect(result.state.mode == .previous)
        #expect(result.state.searchText == "falcon")
        #expect(result.state.launches.isEmpty)
        guard case let .load(mode, searchText, _, _, fetchPolicy, kind, errorPresentation, _) = result.effect else {
            Issue.record("Expected load effect")
            return
        }
        #expect(mode == .previous)
        #expect(searchText == "falcon")
        #expect(fetchPolicy == .useCache)
        #expect(kind == .fresh)
        #expect(errorPresentation == .initial)
    }

    @Test("searchTextChanged updates text without loading")
    static func searchTextChangedUpdatesTextOnly() {
        let state = LaunchListState(mode: .upcoming, launches: [makeLaunch(id: "1")], pagination: .initial, phase: .loaded)

        let result = LaunchListReducer.reduce(state: state, action: .searchTextChanged("moon"))

        #expect(result.state.searchText == "moon")
        #expect(result.state.launches.count == 1)
        #expect(result.state.phase == .loaded)
        #expect(result.effect == nil)
    }

    @Test("searchTextChanged clears a stale load-more error")
    static func searchTextChangedClearsStaleLoadMoreError() {
        let state = LaunchListState(
            mode: .upcoming,
            launches: [makeLaunch(id: "1")],
            pagination: .initial.failingLoadMore(message: "failed"),
            phase: .loaded
        )

        let result = LaunchListReducer.reduce(state: state, action: .searchTextChanged("moon"))

        #expect(result.state.pagination.loadMoreError == nil)
    }

    @Test("search starts a fresh load for the debounced text")
    static func searchStartsFreshLoad() {
        let state = LaunchListState(mode: .upcoming, launches: [makeLaunch(id: "1")], searchText: "moon", pagination: .initial, phase: .loaded)

        let result = LaunchListReducer.reduce(state: state, action: .search("moon"))

        #expect(result.state.launches.isEmpty)
        #expect(result.state.phase == .loading(.initial))
        guard case let .load(mode, searchText, page, previousLaunches, fetchPolicy, kind, errorPresentation, _) = result.effect else {
            Issue.record("Expected load effect")
            return
        }
        #expect(mode == .upcoming)
        #expect(searchText == "moon")
        #expect(page == 1)
        #expect(previousLaunches.isEmpty)
        #expect(fetchPolicy == .useCache)
        #expect(kind == .fresh)
        #expect(errorPresentation == .initial)
    }

    @Test("A response for a superseded search is dropped")
    static func staleSearchResponseIsDropped() {
        let state = LaunchListState(mode: .upcoming, launches: [], searchText: "moon", pagination: .initial, phase: .loading(.initial))

        let result = LaunchListReducer.reduce(
            state: state,
            action: .loadResponse(
                mode: .upcoming,
                searchText: "mars",
                previousLaunches: [],
                page: PagedResult(items: [makeLaunch(id: "stale")], currentPage: 1),
                kind: .fresh,
                errorPresentation: .initial,
                errorMessage: nil,
                generation: 0
            )
        )

        #expect(result.state.launches.isEmpty)
        #expect(result.state == state)
    }

    @Test("An initial-load failure blanks the screen regardless of previousLaunches")
    static func initialLoadFailureBlanksScreen() {
        let previousLaunches = [makeLaunch(id: "stale-from-a-prior-mode")]
        let errorMessage = "Network failed"

        let result = LaunchListReducer.reduce(
            state: LaunchListState(
                mode: .upcoming,
                launches: [],
                pagination: .initial,
                phase: .loading(.initial)
            ),
            action: .loadResponse(
                mode: .upcoming,
                searchText: "",
                // Even if a caller mistakenly passed a non-empty `previousLaunches` for an
                // `.initial` load, `errorPresentation`, not this value, decides the outcome.
                previousLaunches: previousLaunches,
                page: PagedResult(items: [], currentPage: 1),
                kind: .fresh,
                errorPresentation: .initial,
                errorMessage: errorMessage,
                generation: 0
            )
        )

        #expect(result.state.launches.isEmpty)
        if case let .error(message) = result.state.phase {
            #expect(message == errorMessage)
        } else {
            Issue.record("Expected error phase")
        }
    }

    @Test("A refresh failure preserves previous launches instead of blanking the screen")
    static func refreshFailurePreservesLaunches() {
        let previousLaunches = [makeLaunch(id: "keep")]
        let errorMessage = "Network failed"

        let result = LaunchListReducer.reduce(
            state: LaunchListState(
                mode: .upcoming,
                launches: previousLaunches,
                pagination: .initial,
                phase: .loading(.refresh)
            ),
            action: .loadResponse(
                mode: .upcoming,
                searchText: "",
                previousLaunches: previousLaunches,
                page: PagedResult(items: [], currentPage: 1),
                kind: .fresh,
                errorPresentation: .refresh,
                errorMessage: errorMessage,
                generation: 0
            )
        )

        #expect(result.state.mode == .upcoming)
        #expect(result.state.launches == previousLaunches)
        if case let .error(message) = result.state.phase {
            #expect(message == errorMessage)
        } else {
            Issue.record("Expected error phase")
        }
        #expect(result.effect == nil)
    }

    @Test("Load more requests next page with network-only policy")
    static func loadMoreRequestsNextPage() {
        let launches = [makeLaunch(id: "1")]
        let pagination = ListPagination(
            currentPage: 1,
            nextPage: 2,
            previousPage: nil,
            totalCount: 100,
            loadMoreError: nil
        )
        let state = LaunchListState(mode: .upcoming, launches: launches, pagination: pagination, phase: .loaded)

        let result = LaunchListReducer.reduce(state: state, action: .loadMore)

        guard case let .load(mode, _, page, previousLaunches, fetchPolicy, kind, _, _) = result.effect else {
            Issue.record("Expected load-more effect")
            return
        }
        #expect(mode == .upcoming)
        #expect(page == 2)
        #expect(previousLaunches == launches)
        #expect(fetchPolicy == .networkOnly)
        #expect(kind == .loadMore)
        #expect(result.state.phase == .loading(.loadMore))
    }

    @Test("Load-more error stays in loaded state with error in pagination")
    static func loadMoreErrorKeepsLoadedState() {
        let launches = [makeLaunch(id: "1")]
        let pagination = ListPagination(
            currentPage: 1,
            nextPage: 2,
            previousPage: nil,
            totalCount: 100,
            loadMoreError: nil
        )
        let state = LaunchListState(mode: .upcoming, launches: launches, pagination: pagination, phase: .loading(.loadMore))

        let result = LaunchListReducer.reduce(
            state: state,
            action: .loadResponse(
                mode: .upcoming,
                searchText: "",
                previousLaunches: launches,
                page: PagedResult(items: [], currentPage: 2),
                kind: .loadMore,
                errorPresentation: .refresh,
                errorMessage: "Network failed",
                generation: 0
            )
        )

        #expect(result.state.mode == .upcoming)
        #expect(result.state.launches == launches)
        #expect(result.state.phase == .loaded)
        #expect(result.state.pagination.loadMoreError == "Network failed")
        #expect(result.state.pagination.nextPage == 2)
        #expect(result.effect == nil)
    }

    @Test("Load more is blocked when loadMoreError is present")
    static func loadMoreBlockedByError() {
        let launches = [makeLaunch(id: "1")]
        let pagination = ListPagination(
            currentPage: 1,
            nextPage: 2,
            previousPage: nil,
            totalCount: 100,
            loadMoreError: "Previous failure"
        )
        let state = LaunchListState(mode: .upcoming, launches: launches, pagination: pagination, phase: .loaded)

        let result = LaunchListReducer.reduce(state: state, action: .loadMore)

        #expect(result.effect == nil)
    }

    @Test("Load more is blocked while already loading next page")
    static func loadMoreBlockedWhileLoading() {
        let launches = [makeLaunch(id: "1")]
        let pagination = ListPagination(
            currentPage: 1,
            nextPage: 2,
            previousPage: nil,
            totalCount: 100,
            loadMoreError: nil
        )
        let state = LaunchListState(mode: .upcoming, launches: launches, pagination: pagination, phase: .loading(.loadMore))

        let result = LaunchListReducer.reduce(state: state, action: .loadMore)

        #expect(result.effect == nil)
    }

    @Test("Retry load more clears error and triggers load")
    static func retryLoadMoreClearsErrorAndLoads() {
        let launches = [makeLaunch(id: "1")]
        let pagination = ListPagination(
            currentPage: 1,
            nextPage: 2,
            previousPage: nil,
            totalCount: 100,
            loadMoreError: "Previous failure"
        )
        let state = LaunchListState(mode: .upcoming, launches: launches, pagination: pagination, phase: .loaded)

        let result = LaunchListReducer.reduce(state: state, action: .retryLoadMore)

        guard case let .load(mode, _, page, previousLaunches, fetchPolicy, kind, _, _) = result.effect else {
            Issue.record("Expected load effect from retry")
            return
        }
        #expect(mode == .upcoming)
        #expect(page == 2)
        #expect(previousLaunches == launches)
        #expect(fetchPolicy == .networkOnly)
        #expect(kind == .loadMore)
        #expect(result.state.phase == .loading(.loadMore))
        #expect(result.state.pagination.loadMoreError == nil)
    }

    @Test("A response for a superseded generation is dropped")
    static func staleGenerationResponseIsDropped() {
        // Two overlapping refreshes (e.g. rapid pull-to-refresh) share the same mode/search
        // text, so only the generation guard, not those checks, can tell them apart. The
        // reducer's own `.refresh` guard now blocks a second refresh while one is in flight, so
        // this drives the state transition directly via `startingRefresh()` (the same call the
        // reducer itself makes) to exercise the generation guard in isolation, independent of
        // that reducer-level idempotency check.
        let loadedState = LaunchListState(
            mode: .upcoming,
            launches: [makeLaunch(id: "existing")],
            pagination: .initial,
            phase: .loaded
        )
        let (firstRefreshState, _) = loadedState.startingRefresh()
        let (secondRefreshState, _) = firstRefreshState.startingRefresh()

        let staleResult = LaunchListReducer.reduce(
            state: secondRefreshState,
            action: .loadResponse(
                mode: .upcoming,
                searchText: "",
                previousLaunches: [],
                page: PagedResult(items: [makeLaunch(id: "stale")], currentPage: 1),
                kind: .fresh,
                errorPresentation: .refresh,
                errorMessage: nil,
                generation: 1
            )
        )

        #expect(staleResult.state == secondRefreshState)

        let currentResult = LaunchListReducer.reduce(
            state: secondRefreshState,
            action: .loadResponse(
                mode: .upcoming,
                searchText: "",
                previousLaunches: [],
                page: PagedResult(items: [makeLaunch(id: "current")], currentPage: 1),
                kind: .fresh,
                errorPresentation: .refresh,
                errorMessage: nil,
                generation: 2
            )
        )

        #expect(currentResult.state.launches.map(\.id) == ["current"])
    }

    @Test("A response for a superseded mode is dropped even with a matching generation")
    static func staleModeResponseIsDropped() {
        let state = LaunchListState(mode: .previous, launches: [], pagination: .initial, phase: .loading(.initial))

        let result = LaunchListReducer.reduce(
            state: state,
            action: .loadResponse(
                mode: .upcoming,
                searchText: "",
                previousLaunches: [],
                page: PagedResult(items: [makeLaunch(id: "wrong-mode")], currentPage: 1),
                kind: .fresh,
                errorPresentation: .initial,
                errorMessage: nil,
                generation: 0
            )
        )

        #expect(result.state == state)
    }

    @Test("Cancelling an in-flight initial load reverts to idle so a future appear can restart it")
    static func cancellingInitialLoadRevertsToIdle() {
        let state = LaunchListState(mode: .upcoming, launches: [], pagination: .initial, phase: .loading(.initial))

        let result = LaunchListReducer.reduce(state: state, action: .cancelled)

        #expect(result.state.phase == .idle)
        #expect(result.effect == nil)
    }

    // A task that doesn't observe cancellation in time (e.g. coalesced onto another caller's
    // in-flight `.useCache` fetch, per `InFlightRequestStore`) can still resolve and call
    // `send(.loadResponse(...))` after `cancelInFlightWork()` already reverted `phase`. Without
    // `.cancelled` also bumping the generation, that late response would pass
    // `applyingLoadResponse`'s guard and resurrect state the reducer already moved past.
    @Test("Cancelling an in-flight load invalidates its generation, so a late response is dropped")
    static func cancellingInvalidatesGenerationForLateResponse() {
        let (loadingState, generation) = LaunchListState(
            mode: .upcoming, launches: [], pagination: .initial, phase: .idle
        ).startingInitialLoad()

        let cancelledState = LaunchListReducer.reduce(state: loadingState, action: .cancelled).state
        #expect(cancelledState.phase == .idle)

        let lateResponseResult = LaunchListReducer.reduce(
            state: cancelledState,
            action: .loadResponse(
                mode: .upcoming,
                searchText: "",
                previousLaunches: [],
                page: PagedResult(items: [makeLaunch(id: "late")], currentPage: 1),
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
        let launches = [makeLaunch(id: "existing")]

        let refreshResult = LaunchListReducer.reduce(
            state: LaunchListState(mode: .upcoming, launches: launches, pagination: .initial, phase: .loading(.refresh)),
            action: .cancelled
        )
        #expect(refreshResult.state.phase == .loaded)
        #expect(refreshResult.state.launches == launches)

        let loadMoreResult = LaunchListReducer.reduce(
            state: LaunchListState(mode: .upcoming, launches: launches, pagination: .initial, phase: .loading(.loadMore)),
            action: .cancelled
        )
        #expect(loadMoreResult.state.phase == .loaded)
        #expect(loadMoreResult.state.launches == launches)
    }

    @Test("Cancelling is a no-op outside a loading phase")
    static func cancellingIsANoOpOutsideLoadingPhase() {
        let idleState = LaunchListState(mode: .upcoming, launches: [], pagination: .initial, phase: .idle)
        #expect(LaunchListReducer.reduce(state: idleState, action: .cancelled).state == idleState)

        let loadedState = LaunchListState(mode: .upcoming, launches: [makeLaunch(id: "1")], pagination: .initial, phase: .loaded)
        #expect(LaunchListReducer.reduce(state: loadedState, action: .cancelled).state == loadedState)

        let errorState = LaunchListState(mode: .upcoming, launches: [], pagination: .initial, phase: .error(message: "failed"))
        #expect(LaunchListReducer.reduce(state: errorState, action: .cancelled).state == errorState)
    }
}

private extension LaunchListReducerTests {
    static func makeLaunch(id: String) -> Launch {
        Launch(
            id: id,
            name: "Launch \(id)",
            status: .go,
            windowStart: Date(timeIntervalSince1970: 1000),
            windowEnd: nil,
            rocket: LaunchRocket(id: 1, name: "Falcon 9"),
            launchPad: LaunchPad(id: "10", name: "LC-39A", latitude: 0, longitude: 0, locationName: "KSC"),
            mission: nil,
            imageURL: nil,
            webcastURL: nil
        )
    }
}

//
//  LaunchListReducerTests.swift
//  TMinusTests
//
//  Created by Sadegh on 12/05/2026.
//

@testable import TMinus
import Testing
import Foundation

// MARK: - LaunchListReducerTests

@Suite("LaunchListReducer")
enum LaunchListReducerTests {
    @Test("Appear loads current mode using cache")
    static func appearLoadsCurrentMode() {
        let state = LaunchListState(mode: .upcoming, launches: [], pagination: .initial, phase: .idle)

        let result = LaunchListReducer.reduce(state: state, action: .appear)

        #expect(result.state.mode == .upcoming)
        #expect(result.state.launches.isEmpty)
        #expect(result.state.phase == .loading(.initial))
        guard case let .load(mode, page, previousLaunches, fetchPolicy, kind, _) = result.effect else {
            Issue.record("Expected load effect")
            return
        }
        #expect(mode == .upcoming)
        #expect(page == 1)
        #expect(previousLaunches.isEmpty)
        #expect(fetchPolicy == .useCache)
        #expect(kind == .fresh)
    }

    @Test("Refresh keeps previous launches and reloads ignoring cache")
    static func refreshKeepsPreviousLaunches() {
        let previousLaunches = [makeLaunch(id: "1"), makeLaunch(id: "2")]
        let state = LaunchListState(mode: .previous, launches: previousLaunches, pagination: .initial, phase: .loaded)

        let result = LaunchListReducer.reduce(state: state, action: .refresh)

        #expect(result.state.mode == .previous)
        #expect(result.state.launches == previousLaunches)
        #expect(result.state.phase == .loading(.refresh))
        guard case let .load(mode, page, launches, fetchPolicy, kind, _) = result.effect else {
            Issue.record("Expected load effect")
            return
        }
        #expect(mode == .previous)
        #expect(page == 1)
        #expect(launches == previousLaunches)
        #expect(fetchPolicy == .networkOnly)
        #expect(kind == .fresh)
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

    @Test("Load response with error keeps previous launches")
    static func loadResponseWithError() {
        let previousLaunches = [makeLaunch(id: "keep")]
        let errorMessage = "Network failed"

        let result = LaunchListReducer.reduce(
            state: LaunchListState(
                mode: .upcoming,
                launches: previousLaunches,
                pagination: .initial,
                phase: .loading(.initial)),
            action: .loadResponse(
                mode: .upcoming,
                previousLaunches: previousLaunches,
                page: PagedResult(items: [], currentPage: 1),
                kind: .fresh,
                errorMessage: errorMessage,
                generation: 0))

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
            loadMoreError: nil)
        let state = LaunchListState(mode: .upcoming, launches: launches, pagination: pagination, phase: .loaded)

        let result = LaunchListReducer.reduce(state: state, action: .loadMore)

        guard case let .load(mode, page, previousLaunches, fetchPolicy, kind, _) = result.effect else {
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
            loadMoreError: nil)
        let state = LaunchListState(mode: .upcoming, launches: launches, pagination: pagination, phase: .loading(.loadMore))

        let result = LaunchListReducer.reduce(
            state: state,
            action: .loadResponse(
                mode: .upcoming,
                previousLaunches: launches,
                page: PagedResult(items: [], currentPage: 2),
                kind: .loadMore,
                errorMessage: "Network failed",
                generation: 0))

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
            loadMoreError: "Previous failure")
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
            loadMoreError: nil)
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
            loadMoreError: "Previous failure")
        let state = LaunchListState(mode: .upcoming, launches: launches, pagination: pagination, phase: .loaded)

        let result = LaunchListReducer.reduce(state: state, action: .retryLoadMore)

        guard case let .load(mode, page, previousLaunches, fetchPolicy, kind, _) = result.effect else {
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
        let appeared = LaunchListReducer.reduce(
            state: LaunchListState(mode: .upcoming, launches: [], pagination: .initial, phase: .idle),
            action: .appear)
        // A second appear-triggered load never happens in practice (onAppear only fires once),
        // but modelling it here is the simplest way to advance the generation past the first
        // load's, simulating a fresh load starting while the first is still in flight.
        let refreshed = LaunchListReducer.reduce(state: appeared.state, action: .refresh)

        let staleResult = LaunchListReducer.reduce(
            state: refreshed.state,
            action: .loadResponse(
                mode: .upcoming,
                previousLaunches: [],
                page: PagedResult(items: [makeLaunch(id: "stale")], currentPage: 1),
                kind: .fresh,
                errorMessage: nil,
                generation: 1))

        #expect(staleResult.state == refreshed.state)

        let currentResult = LaunchListReducer.reduce(
            state: refreshed.state,
            action: .loadResponse(
                mode: .upcoming,
                previousLaunches: [],
                page: PagedResult(items: [makeLaunch(id: "current")], currentPage: 1),
                kind: .fresh,
                errorMessage: nil,
                generation: 2))

        #expect(currentResult.state.launches.map(\.id) == ["current"])
    }
}

extension LaunchListReducerTests {
    fileprivate static func makeLaunch(id: String) -> Launch {
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
            webcastURL: nil)
    }
}

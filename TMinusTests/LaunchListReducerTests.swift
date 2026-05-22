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
        let state: LaunchListState = .idle(mode: .upcoming)

        let result = LaunchListReducer.reduce(state: state, action: .appear)

        #expect(result.state.mode == .upcoming)
        #expect(result.state.launches.isEmpty)
        guard case let .load(mode, page, previousLaunches, fetchPolicy, isLoadMore) = result.effect else {
            Issue.record("Expected load effect")
            return
        }
        #expect(mode == .upcoming)
        #expect(page == 1)
        #expect(previousLaunches.isEmpty)
        #expect(fetchPolicy == .useCache)
        #expect(isLoadMore == false)
    }

    @Test("Refresh keeps previous launches and reloads ignoring cache")
    static func refreshKeepsPreviousLaunches() {
        let previousLaunches = [makeLaunch(id: "1"), makeLaunch(id: "2")]
        let state: LaunchListState = .loaded(
            mode: .previous,
            launches: previousLaunches,
            pagination: .initial)

        let result = LaunchListReducer.reduce(state: state, action: .refresh)

        #expect(result.state.mode == .previous)
        #expect(result.state.launches == previousLaunches)
        guard case let .load(mode, page, launches, fetchPolicy, isLoadMore) = result.effect else {
            Issue.record("Expected load effect")
            return
        }
        #expect(mode == .previous)
        #expect(page == 1)
        #expect(launches == previousLaunches)
        #expect(fetchPolicy == .networkOnly)
        #expect(isLoadMore == false)
    }

    @Test("Mode change to same mode has no effect")
    static func modeChangedToSameModeNoEffect() {
        let launches = [makeLaunch(id: "x")]
        let state: LaunchListState = .loaded(
            mode: .upcoming,
            launches: launches,
            pagination: .initial)

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
            state: .loading(mode: .upcoming, launches: previousLaunches, pagination: .initial),
            action: .loadResponse(
                mode: .upcoming,
                previousLaunches: previousLaunches,
                page: PagedResult(items: [], currentPage: 1),
                isLoadMore: false,
                errorMessage: errorMessage))

        #expect(result.state.mode == .upcoming)
        #expect(result.state.launches == previousLaunches)
        #expect(result.effect == nil)
    }

    @Test("Load more requests next page with network-only policy")
    static func loadMoreRequestsNextPage() {
        let launches = [makeLaunch(id: "1")]
        let pagination = LaunchListPagination(
            currentPage: 1,
            nextPage: 2,
            previousPage: nil,
            totalCount: 100,
            isLoadingMore: false,
            loadMoreError: nil)
        let state: LaunchListState = .loaded(mode: .upcoming, launches: launches, pagination: pagination)

        let result = LaunchListReducer.reduce(state: state, action: .loadMore)

        guard case let .load(mode, page, previousLaunches, fetchPolicy, isLoadMore) = result.effect else {
            Issue.record("Expected load-more effect")
            return
        }
        #expect(mode == .upcoming)
        #expect(page == 2)
        #expect(previousLaunches == launches)
        #expect(fetchPolicy == .networkOnly)
        #expect(isLoadMore == true)
        #expect(result.state.pagination.isLoadingMore == true)
    }

    @Test("Load-more error stays in loaded state with error in pagination")
    static func loadMoreErrorKeepsLoadedState() {
        let launches = [makeLaunch(id: "1")]
        let pagination = LaunchListPagination(
            currentPage: 1,
            nextPage: 2,
            previousPage: nil,
            totalCount: 100,
            isLoadingMore: true,
            loadMoreError: nil)
        let state: LaunchListState = .loading(mode: .upcoming, launches: launches, pagination: pagination)

        let result = LaunchListReducer.reduce(
            state: state,
            action: .loadResponse(
                mode: .upcoming,
                previousLaunches: launches,
                page: PagedResult(items: [], currentPage: 2),
                isLoadMore: true,
                errorMessage: "Network failed"))

        if case let .loaded(mode, resultLaunches, resultPagination) = result.state {
            #expect(mode == .upcoming)
            #expect(resultLaunches == launches)
            #expect(resultPagination.loadMoreError == "Network failed")
            #expect(resultPagination.isLoadingMore == false)
            #expect(resultPagination.nextPage == 2)
        } else {
            Issue.record("Expected loaded state, got \(result.state)")
        }
        #expect(result.effect == nil)
    }

    @Test("Load more is blocked when loadMoreError is present")
    static func loadMoreBlockedByError() {
        let launches = [makeLaunch(id: "1")]
        let pagination = LaunchListPagination(
            currentPage: 1,
            nextPage: 2,
            previousPage: nil,
            totalCount: 100,
            isLoadingMore: false,
            loadMoreError: "Previous failure")
        let state: LaunchListState = .loaded(mode: .upcoming, launches: launches, pagination: pagination)

        let result = LaunchListReducer.reduce(state: state, action: .loadMore)

        #expect(result.effect == nil)
    }

    @Test("Retry load more clears error and triggers load")
    static func retryLoadMoreClearsErrorAndLoads() {
        let launches = [makeLaunch(id: "1")]
        let pagination = LaunchListPagination(
            currentPage: 1,
            nextPage: 2,
            previousPage: nil,
            totalCount: 100,
            isLoadingMore: false,
            loadMoreError: "Previous failure")
        let state: LaunchListState = .loaded(mode: .upcoming, launches: launches, pagination: pagination)

        let result = LaunchListReducer.reduce(state: state, action: .retryLoadMore)

        guard case let .load(mode, page, previousLaunches, fetchPolicy, isLoadMore) = result.effect else {
            Issue.record("Expected load effect from retry")
            return
        }
        #expect(mode == .upcoming)
        #expect(page == 2)
        #expect(previousLaunches == launches)
        #expect(fetchPolicy == .networkOnly)
        #expect(isLoadMore == true)
        #expect(result.state.pagination.isLoadingMore == true)
        #expect(result.state.pagination.loadMoreError == nil)
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

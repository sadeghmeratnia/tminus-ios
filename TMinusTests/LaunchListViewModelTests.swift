//
//  LaunchListViewModelTests.swift
//  TMinusTests
//
//  Created by Sadegh on 12/05/2026.
//

import Foundation
import Testing
@testable import TMinus

// MARK: - LaunchListViewModelTests

@MainActor
@Suite("LaunchListViewModel")
struct LaunchListViewModelTests {
    @Test("onAppear loads upcoming launches only once")
    func onAppearLoadsOnce() async throws {
        let repository = MockLaunchRepository()
        await repository.setUpcomingHandler { _, _ in
            PagedResult(items: [Self.makeLaunch(id: "upcoming-1")])
        }
        let viewModel = Self.makeViewModel(repository: repository)

        viewModel.onTrigger(.onAppear)
        try await waitUntil {
            viewModel.state.phase == .loaded
                && viewModel.state.mode == .upcoming
                && viewModel.state.launches.map(\.id) == ["upcoming-1"]
        }

        viewModel.onTrigger(.onAppear)
        try await Task.sleep(for: .nanoseconds(50_000_000))

        let upcomingQueries = await repository.upcomingQueries
        #expect(upcomingQueries.count == 1)
        #expect(upcomingQueries.first?.fetchPolicy == .useCache)
    }

    @Test("refresh bypasses cache and keeps previous launches while loading")
    func refreshBypassesCache() async throws {
        let repository = MockLaunchRepository()
        await repository.setUpcomingHandler { query, _ in
            if query.fetchPolicy == .networkOnly {
                return PagedResult(items: [Self.makeLaunch(id: "fresh")])
            }
            return PagedResult(items: [Self.makeLaunch(id: "cached")])
        }
        let viewModel = Self.makeViewModel(repository: repository)

        viewModel.onTrigger(.onAppear)
        try await waitUntil {
            viewModel.state.phase == .loaded
                && viewModel.state.launches.map(\.id) == ["cached"]
        }

        viewModel.onTrigger(.refresh)
        #expect(viewModel.state.phase == .loading(.refresh))
        #expect(viewModel.state.launches.map(\.id) == ["cached"])

        try await waitUntil {
            viewModel.state.phase == .loaded
                && viewModel.state.launches.map(\.id) == ["fresh"]
        }

        let upcomingQueries = await repository.upcomingQueries
        #expect(upcomingQueries.count == 2)
        #expect(upcomingQueries.map(\.fetchPolicy) == [.useCache, .networkOnly])
    }

    @Test("mode change loads previous launches without bypassing cache")
    func modeChangeLoadsPrevious() async throws {
        let repository = MockLaunchRepository()
        await repository.setUpcomingHandler { _, _ in
            PagedResult(items: [Self.makeLaunch(id: "upcoming")])
        }
        await repository.setPreviousHandler { _, _ in
            PagedResult(items: [Self.makeLaunch(id: "previous")])
        }
        let viewModel = Self.makeViewModel(repository: repository)

        viewModel.onTrigger(.onAppear)
        try await waitUntil {
            viewModel.state.phase == .loaded
                && viewModel.state.mode == .upcoming
                && viewModel.state.launches.map(\.id) == ["upcoming"]
        }

        viewModel.onTrigger(.modeChanged(.previous))
        #expect(viewModel.state.phase == .loading(.initial))
        #expect(viewModel.state.mode == .previous)
        #expect(viewModel.state.launches.isEmpty)

        try await waitUntil {
            viewModel.state.phase == .loaded
                && viewModel.state.mode == .previous
                && viewModel.state.launches.map(\.id) == ["previous"]
        }

        let previousQueries = await repository.previousQueries
        #expect(previousQueries.count == 1)
        #expect(previousQueries.first?.fetchPolicy == .useCache)
    }

    @Test("search text change debounces before triggering a load")
    func searchDebounces() async throws {
        let repository = MockLaunchRepository()
        await repository.setUpcomingHandler { query, _ in
            PagedResult(items: [Self.makeLaunch(id: query.searchText ?? "none")])
        }
        let viewModel = Self.makeViewModel(repository: repository)

        viewModel.onTrigger(.onAppear)
        try await waitUntil { viewModel.state.phase == .loaded }

        viewModel.onTrigger(.searchTextChanged("f"))
        viewModel.onTrigger(.searchTextChanged("fa"))
        viewModel.onTrigger(.searchTextChanged("falcon"))

        // Immediately after typing, the search text is reflected but no load has fired yet.
        #expect(viewModel.state.searchText == "falcon")
        try await Task.sleep(for: .nanoseconds(100_000_000))
        let queriesRightAfterTyping = await repository.upcomingQueries
        #expect(queriesRightAfterTyping.count == 1, "Only the initial appear load should have fired so far")

        try await waitUntil {
            viewModel.state.phase == .loaded && viewModel.state.launches.map(\.id) == ["falcon"]
        }

        let queries = await repository.upcomingQueries
        #expect(queries.map(\.searchText).last == "falcon")
        #expect(
            queries.filter { $0.searchText == "f" || $0.searchText == "fa" }.isEmpty,
            "Intermediate keystrokes must not trigger loads"
        )
    }

    @Test("a second refresh trigger while one is already in flight is a no-op")
    func secondRefreshWhileInFlightIsANoOp() async throws {
        // `LaunchListReducer.refresh` now guards against firing while `.loading(.refresh)` is
        // already the phase (see `LaunchListReducerTests.refreshIsANoOpWhileAlreadyRefreshing`),
        // so two rapid `.refresh` triggers produce exactly one network request rather than a
        // race between two in-flight loads.
        let repository = MockLaunchRepository()
        await repository.setUpcomingHandler { query, callIndex in
            if callIndex == 1 {
                return PagedResult(items: [Self.makeLaunch(id: "initial")])
            }
            try await Task.sleep(for: .nanoseconds(200_000_000))
            #expect(query.fetchPolicy == .networkOnly)
            return PagedResult(items: [Self.makeLaunch(id: "fresh")])
        }
        let viewModel = Self.makeViewModel(repository: repository)

        viewModel.onTrigger(.onAppear)
        try await waitUntil { viewModel.state.launches.map(\.id) == ["initial"] }

        viewModel.onTrigger(.refresh)
        viewModel.onTrigger(.refresh)

        try await waitUntil {
            viewModel.state.phase == .loaded
                && viewModel.state.launches.map(\.id) == ["fresh"]
        }

        let upcomingQueries = await repository.upcomingQueries
        #expect(upcomingQueries.count == 2)
        #expect(upcomingQueries.map(\.fetchPolicy) == [.useCache, .networkOnly])
    }

    @Test("retyping a search that's already loaded does not trigger a redundant load")
    func searchSkipsRedundantReloadForAlreadyLoadedText() async throws {
        let repository = MockLaunchRepository()
        await repository.setUpcomingHandler { query, _ in
            PagedResult(items: [Self.makeLaunch(id: query.searchText ?? "none")])
        }
        let viewModel = Self.makeViewModel(repository: repository)

        viewModel.onTrigger(.onAppear)
        try await waitUntil { viewModel.state.phase == .loaded }

        viewModel.onTrigger(.searchTextChanged("falcon"))
        try await waitUntil {
            viewModel.state.phase == .loaded && viewModel.state.launches.map(\.id) == ["falcon"]
        }
        let queriesAfterFirstSearch = await repository.upcomingQueries

        // Typing away and back to the exact text that's already loaded must not clear the
        // currently-displayed results or issue another network call for it.
        viewModel.onTrigger(.searchTextChanged("falcons"))
        viewModel.onTrigger(.searchTextChanged("falcon"))
        try await Task.sleep(for: .milliseconds(600))

        #expect(viewModel.state.phase == .loaded)
        #expect(viewModel.state.launches.map(\.id) == ["falcon"])
        let queriesAfterRetyping = await repository.upcomingQueries
        #expect(queriesAfterRetyping.count == queriesAfterFirstSearch.count, "No new query should have been issued")
    }

    @Test("retyping a search that previously failed triggers a retry")
    func searchRetriesAfterPreviousFailure() async throws {
        let repository = MockLaunchRepository()
        await repository.setUpcomingHandler { query, callIndex in
            if query.searchText == "falcon", callIndex == 2 {
                throw NetworkFeatureError.networkUnavailable
            }
            return PagedResult(items: [Self.makeLaunch(id: query.searchText ?? "none")])
        }
        let viewModel = Self.makeViewModel(repository: repository)

        viewModel.onTrigger(.onAppear)
        try await waitUntil { viewModel.state.phase == .loaded }

        viewModel.onTrigger(.searchTextChanged("falcon"))
        try await waitUntil {
            if case .error = viewModel.state.phase { return true }
            return false
        }

        // Retyping the exact same text that just failed must re-dispatch the search rather
        // than being silently swallowed as "already loaded".
        viewModel.onTrigger(.searchTextChanged("falcon"))
        try await waitUntil {
            viewModel.state.phase == .loaded && viewModel.state.launches.map(\.id) == ["falcon"]
        }

        let queries = await repository.upcomingQueries
        #expect(queries.filter { $0.searchText == "falcon" }.count == 2, "The failed search must have been retried")
    }

    @Test("last launch appearance triggers paginated prefetch")
    func launchAppearancePrefetchesNextPage() async throws {
        let repository = MockLaunchRepository()
        await repository.setUpcomingHandler { query, _ in
            if query.page == 1 {
                return PagedResult(
                    items: [Self.makeLaunch(id: "page-1-last")],
                    currentPage: 1,
                    totalCount: 2,
                    nextPage: 2,
                    previousPage: nil
                )
            }
            return PagedResult(
                items: [Self.makeLaunch(id: "page-2-item")],
                currentPage: 2,
                totalCount: 2,
                nextPage: nil,
                previousPage: 1
            )
        }
        let viewModel = Self.makeViewModel(repository: repository)

        viewModel.onTrigger(.onAppear)
        try await waitUntil {
            viewModel.state.phase == .loaded
                && viewModel.state.launches.map(\.id) == ["page-1-last"]
                && viewModel.state.pagination.nextPage == 2
        }

        viewModel.onTrigger(.launchAppeared("page-1-last"))

        try await waitUntil {
            viewModel.state.phase == .loaded
                && viewModel.state.launches.map(\.id) == ["page-1-last", "page-2-item"]
                && viewModel.state.pagination.currentPage == 2
        }

        let upcomingQueries = await repository.upcomingQueries
        #expect(upcomingQueries.map(\.page) == [1, 2])
        #expect(upcomingQueries.map(\.fetchPolicy) == [.useCache, .networkOnly])
    }

    @Test("retrying load-more does not cancel an in-flight refresh")
    func retryLoadMoreDoesNotCancelRefresh() async throws {
        let repository = MockLaunchRepository()
        await repository.setUpcomingHandler { _, callIndex in
            switch callIndex {
            case 1:
                return PagedResult(
                    items: [Self.makeLaunch(id: "page-1-last")],
                    currentPage: 1,
                    totalCount: 2,
                    nextPage: 2,
                    previousPage: nil
                )
            case 2:
                throw NetworkFeatureError.networkUnavailable
            case 3:
                // Slow refresh: still in flight when retry-load-more fires.
                try await Task.sleep(for: .nanoseconds(300_000_000))
                return PagedResult(
                    items: [Self.makeLaunch(id: "fresh")],
                    currentPage: 1,
                    totalCount: 2,
                    nextPage: 2,
                    previousPage: nil
                )
            default:
                return PagedResult(
                    items: [Self.makeLaunch(id: "page-2-item")],
                    currentPage: 2,
                    totalCount: 2,
                    nextPage: nil,
                    previousPage: 1
                )
            }
        }
        let viewModel = Self.makeViewModel(repository: repository)

        viewModel.onTrigger(.onAppear)
        try await waitUntil {
            viewModel.state.phase == .loaded
                && viewModel.state.launches.map(\.id) == ["page-1-last"]
        }

        viewModel.onTrigger(.launchAppeared("page-1-last"))
        try await waitUntil {
            viewModel.state.pagination.loadMoreError != nil
        }

        viewModel.onTrigger(.refresh)
        #expect(viewModel.state.phase == .loading(.refresh))

        viewModel.onTrigger(.retryLoadMore)

        // The refresh response must still land; with a shared task it would be cancelled.
        try await waitUntil {
            viewModel.state.phase == .loaded
                && viewModel.state.launches.map(\.id) == ["fresh"]
        }
    }
}

private extension LaunchListViewModelTests {
    static func makeViewModel(repository: LaunchRepositoryProtocol) -> LaunchListViewModel {
        LaunchListViewModel(
            fetchUpcomingLaunchesUseCase: FetchUpcomingLaunchesUseCase(repository: repository),
            fetchPreviousLaunchesUseCase: FetchPreviousLaunchesUseCase(repository: repository)
        )
    }

    nonisolated static func makeLaunch(id: String) -> Launch {
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

// MARK: - MockLaunchRepository

actor MockLaunchRepository: LaunchRepositoryProtocol {
    private(set) var upcomingQueries: [LaunchListQuery] = []
    private(set) var previousQueries: [LaunchListQuery] = []
    private var upcomingCallCount = 0
    private var previousCallCount = 0

    private var upcomingHandler: (@Sendable (LaunchListQuery, Int) async throws -> PagedResult<Launch>)?
    private var previousHandler: (@Sendable (LaunchListQuery, Int) async throws -> PagedResult<Launch>)?

    func setUpcomingHandler(_ handler: @escaping @Sendable (LaunchListQuery, Int) async throws -> PagedResult<Launch>) {
        upcomingHandler = handler
    }

    func setPreviousHandler(_ handler: @escaping @Sendable (LaunchListQuery, Int) async throws -> PagedResult<Launch>) {
        previousHandler = handler
    }

    func fetchUpcomingLaunches(query: LaunchListQuery) async throws -> PagedResult<Launch> {
        upcomingCallCount += 1
        upcomingQueries.append(query)
        guard let upcomingHandler else { return PagedResult(items: []) }
        return try await upcomingHandler(query, upcomingCallCount)
    }

    func fetchPreviousLaunches(query: LaunchListQuery) async throws -> PagedResult<Launch> {
        previousCallCount += 1
        previousQueries.append(query)
        guard let previousHandler else { return PagedResult(items: []) }
        return try await previousHandler(query, previousCallCount)
    }

    func fetchLaunchDetail(id _: String, fetchPolicy _: FetchPolicy) async throws -> Launch {
        throw NSError(domain: "MockLaunchRepository", code: 404)
    }
}

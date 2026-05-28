//
//  LaunchListViewModelTests.swift
//  TMinusTests
//
//  Created by Sadegh on 12/05/2026.
//

@testable import TMinus
import Testing
import Foundation

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
        try await Self.waitUntil {
            viewModel.state.phase == .loaded
                && viewModel.state.mode == .upcoming
                && viewModel.state.launches.map(\.id) == ["upcoming-1"]
        }

        viewModel.onTrigger(.onAppear)
        try await Task.sleep(nanoseconds: 50_000_000)

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
        try await Self.waitUntil {
            viewModel.state.phase == .loaded
                && viewModel.state.launches.map(\.id) == ["cached"]
        }

        viewModel.onTrigger(.refresh)
        #expect(viewModel.state.phase == .loading(.refresh))
        #expect(viewModel.state.launches.map(\.id) == ["cached"])

        try await Self.waitUntil {
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
        try await Self.waitUntil {
            viewModel.state.phase == .loaded
                && viewModel.state.mode == .upcoming
                && viewModel.state.launches.map(\.id) == ["upcoming"]
        }

        viewModel.onTrigger(.modeChanged(.previous))
        #expect(viewModel.state.phase == .loading(.initial))
        #expect(viewModel.state.mode == .previous)
        #expect(viewModel.state.launches.isEmpty)

        try await Self.waitUntil {
            viewModel.state.phase == .loaded
                && viewModel.state.mode == .previous
                && viewModel.state.launches.map(\.id) == ["previous"]
        }

        let previousQueries = await repository.previousQueries
        #expect(previousQueries.count == 1)
        #expect(previousQueries.first?.fetchPolicy == .useCache)
    }

    @Test("newest request wins when previous load gets cancelled")
    func newestRequestWins() async throws {
        let repository = MockLaunchRepository()
        await repository.setUpcomingHandler { query, callIndex in
            if callIndex == 1 {
                try await Task.sleep(nanoseconds: 500_000_000)
                return PagedResult(items: [Self.makeLaunch(id: "stale")])
            }
            if query.fetchPolicy == .networkOnly {
                return PagedResult(items: [Self.makeLaunch(id: "fresh")])
            }
            return PagedResult(items: [Self.makeLaunch(id: "fallback")])
        }
        let viewModel = Self.makeViewModel(repository: repository)

        viewModel.onTrigger(.onAppear)
        viewModel.onTrigger(.refresh)

        try await Self.waitUntil {
            viewModel.state.phase == .loaded
                && viewModel.state.launches.map(\.id) == ["fresh"]
        }

        let upcomingQueries = await repository.upcomingQueries
        #expect(upcomingQueries.count == 2)
        #expect(upcomingQueries.map(\.fetchPolicy) == [.useCache, .networkOnly])
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
                    previousPage: nil)
            }
            return PagedResult(
                items: [Self.makeLaunch(id: "page-2-item")],
                currentPage: 2,
                totalCount: 2,
                nextPage: nil,
                previousPage: 1)
        }
        let viewModel = Self.makeViewModel(repository: repository)

        viewModel.onTrigger(.onAppear)
        try await Self.waitUntil {
            viewModel.state.phase == .loaded
                && viewModel.state.launches.map(\.id) == ["page-1-last"]
                && viewModel.state.pagination.nextPage == 2
        }

        viewModel.onTrigger(.launchAppeared("page-1-last"))

        try await Self.waitUntil {
            viewModel.state.phase == .loaded
                && viewModel.state.launches.map(\.id) == ["page-1-last", "page-2-item"]
                && viewModel.state.pagination.currentPage == 2
        }

        let upcomingQueries = await repository.upcomingQueries
        #expect(upcomingQueries.map(\.page) == [1, 2])
        #expect(upcomingQueries.map(\.fetchPolicy) == [.useCache, .networkOnly])
    }
}

extension LaunchListViewModelTests {
    fileprivate static func makeViewModel(repository: LaunchRepositoryProtocol) -> LaunchListViewModel {
        LaunchListViewModel(
            fetchUpcomingLaunchesUseCase: FetchUpcomingLaunchesUseCase(repository: repository),
            fetchPreviousLaunchesUseCase: FetchPreviousLaunchesUseCase(repository: repository))
    }

    fileprivate nonisolated static func makeLaunch(id: String) -> Launch {
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

    fileprivate static func waitUntil(timeoutNanoseconds: UInt64 = 1_500_000_000,
                                      checkEveryNanoseconds: UInt64 = 20_000_000,
                                      _ condition: @escaping @MainActor () -> Bool) async throws {
        let start = DispatchTime.now().uptimeNanoseconds
        while DispatchTime.now().uptimeNanoseconds - start < timeoutNanoseconds {
            if await condition() { return }
            try await Task.sleep(nanoseconds: checkEveryNanoseconds)
        }
        Issue.record("Timed out waiting for expected state")
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

    func fetchLaunchDetail(id: String) async throws -> Launch {
        throw NSError(domain: "MockLaunchRepository", code: 404)
    }
}

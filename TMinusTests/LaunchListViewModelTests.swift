//
//  LaunchListViewModelTests.swift
//  TMinusTests
//
//  Created by Codex on 12/05/2026.
//

@testable import TMinus
import Foundation
import Testing

@MainActor
@Suite("LaunchListViewModel")
struct LaunchListViewModelTests {
    @Test("onAppear loads upcoming launches only once")
    func onAppearLoadsOnce() async throws {
        let repository = MockLaunchRepository()
        await repository.setUpcomingHandler { _, _ in
            [Self.makeLaunch(id: "upcoming-1")]
        }
        let viewModel = Self.makeViewModel(repository: repository)

        viewModel.onTrigger(.onAppear)
        try await Self.waitUntil {
            if case let .loaded(mode, launches) = viewModel.state {
                return mode == .upcoming && launches.map(\.id) == ["upcoming-1"]
            }
            return false
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
                return [Self.makeLaunch(id: "fresh")]
            }
            return [Self.makeLaunch(id: "cached")]
        }
        let viewModel = Self.makeViewModel(repository: repository)

        viewModel.onTrigger(.onAppear)
        try await Self.waitUntil {
            if case let .loaded(_, launches) = viewModel.state {
                return launches.map(\.id) == ["cached"]
            }
            return false
        }

        viewModel.onTrigger(.refresh)
        if case let .loading(_, launches) = viewModel.state {
            #expect(launches.map(\.id) == ["cached"])
        } else {
            Issue.record("Expected loading state immediately after refresh")
        }

        try await Self.waitUntil {
            if case let .loaded(_, launches) = viewModel.state {
                return launches.map(\.id) == ["fresh"]
            }
            return false
        }

        let upcomingQueries = await repository.upcomingQueries
        #expect(upcomingQueries.count == 2)
        #expect(upcomingQueries.map(\.fetchPolicy) == [.useCache, .networkOnly])
    }

    @Test("mode change loads previous launches without bypassing cache")
    func modeChangeLoadsPrevious() async throws {
        let repository = MockLaunchRepository()
        await repository.setUpcomingHandler { _, _ in [Self.makeLaunch(id: "upcoming")] }
        await repository.setPreviousHandler { _, _ in [Self.makeLaunch(id: "previous")] }
        let viewModel = Self.makeViewModel(repository: repository)

        viewModel.onTrigger(.onAppear)
        try await Self.waitUntil {
            if case let .loaded(mode, launches) = viewModel.state {
                return mode == .upcoming && launches.map(\.id) == ["upcoming"]
            }
            return false
        }

        viewModel.onTrigger(.modeChanged(.previous))
        if case let .loading(mode, launches) = viewModel.state {
            #expect(mode == .previous)
            #expect(launches.isEmpty)
        } else {
            Issue.record("Expected loading(previous) state after changing mode")
        }

        try await Self.waitUntil {
            if case let .loaded(mode, launches) = viewModel.state {
                return mode == .previous && launches.map(\.id) == ["previous"]
            }
            return false
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
                return [Self.makeLaunch(id: "stale")]
            }
            if query.fetchPolicy == .networkOnly {
                return [Self.makeLaunch(id: "fresh")]
            }
            return [Self.makeLaunch(id: "fallback")]
        }
        let viewModel = Self.makeViewModel(repository: repository)

        viewModel.onTrigger(.onAppear)
        viewModel.onTrigger(.refresh)

        try await Self.waitUntil {
            if case let .loaded(_, launches) = viewModel.state {
                return launches.map(\.id) == ["fresh"]
            }
            return false
        }

        let upcomingQueries = await repository.upcomingQueries
        #expect(upcomingQueries.count == 2)
        #expect(upcomingQueries.map(\.fetchPolicy) == [.useCache, .networkOnly])
    }
}

private extension LaunchListViewModelTests {
    static func makeViewModel(repository: LaunchRepositoryProtocol) -> LaunchListViewModel {
        LaunchListViewModel(
            fetchUpcomingLaunchesUseCase: FetchUpcomingLaunchesUseCase(repository: repository),
            fetchPreviousLaunchesUseCase: FetchPreviousLaunchesUseCase(repository: repository))
    }

    nonisolated static func makeLaunch(id: String) -> Launch {
        Launch(
            id: id,
            name: "Launch \(id)",
            status: .go,
            windowStart: Date(timeIntervalSince1970: 1_000),
            windowEnd: nil,
            rocket: LaunchRocket(id: 1, name: "Falcon 9"),
            launchPad: LaunchPad(id: "10", name: "LC-39A", latitude: 0, longitude: 0, locationName: "KSC"),
            mission: nil,
            imageURL: nil,
            webcastURL: nil)
    }

    static func waitUntil(timeoutNanoseconds: UInt64 = 1_500_000_000,
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

actor MockLaunchRepository: LaunchRepositoryProtocol {
    private(set) var upcomingQueries: [LaunchListQuery] = []
    private(set) var previousQueries: [LaunchListQuery] = []
    private var upcomingCallCount = 0
    private var previousCallCount = 0

    private var upcomingHandler: (@Sendable (LaunchListQuery, Int) async throws -> [Launch])?
    private var previousHandler: (@Sendable (LaunchListQuery, Int) async throws -> [Launch])?

    func setUpcomingHandler(_ handler: @escaping @Sendable (LaunchListQuery, Int) async throws -> [Launch]) {
        upcomingHandler = handler
    }

    func setPreviousHandler(_ handler: @escaping @Sendable (LaunchListQuery, Int) async throws -> [Launch]) {
        previousHandler = handler
    }

    func fetchUpcomingLaunches(query: LaunchListQuery) async throws -> [Launch] {
        upcomingCallCount += 1
        upcomingQueries.append(query)
        guard let upcomingHandler else { return [] }
        return try await upcomingHandler(query, upcomingCallCount)
    }

    func fetchPreviousLaunches(query: LaunchListQuery) async throws -> [Launch] {
        previousCallCount += 1
        previousQueries.append(query)
        guard let previousHandler else { return [] }
        return try await previousHandler(query, previousCallCount)
    }

    func fetchLaunchDetail(id: String) async throws -> Launch {
        throw NSError(domain: "MockLaunchRepository", code: 404)
    }
}

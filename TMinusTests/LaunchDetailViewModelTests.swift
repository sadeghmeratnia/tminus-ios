//
//  LaunchDetailViewModelTests.swift
//  TMinusTests
//
//  Created by Sadegh on 28/05/2026.
//

@testable import TMinus
import Testing
import Foundation

@MainActor
@Suite("LaunchDetailViewModel")
struct LaunchDetailViewModelTests {
    @Test("onAppear loads launch detail once")
    func onAppearLoadsOnce() async throws {
        let repository = MockLaunchDetailRepository()
        await repository.setHandler { id, _ in
            LaunchDetailViewModelTests.makeLaunch(id: id)
        }
        let viewModel = LaunchDetailViewModel(
            launchID: "detail-1",
            fetchLaunchDetailUseCase: FetchLaunchDetailUseCase(repository: repository))

        viewModel.onTrigger(.onAppear)
        try await Self.waitUntil {
            viewModel.state.phase == .loaded
                && viewModel.state.launch?.id == "detail-1"
        }

        viewModel.onTrigger(.onAppear)
        try await Task.sleep(nanoseconds: 50_000_000)

        let requestedIDs = await repository.requestedIDs
        #expect(requestedIDs == ["detail-1"])
    }

    @Test("retry reloads after failure")
    func retryReloadsAfterFailure() async throws {
        let repository = MockLaunchDetailRepository()
        await repository.setHandler { id, callIndex in
            if callIndex == 1 {
                throw LaunchError.networkUnavailable
            }
            return LaunchDetailViewModelTests.makeLaunch(id: id)
        }
        let viewModel = LaunchDetailViewModel(
            launchID: "detail-1",
            fetchLaunchDetailUseCase: FetchLaunchDetailUseCase(repository: repository))

        viewModel.onTrigger(.onAppear)
        try await Self.waitUntil {
            if case .error = viewModel.state.phase { return true }
            return false
        }

        viewModel.onTrigger(.retry)
        try await Self.waitUntil {
            viewModel.state.phase == .loaded
                && viewModel.state.launch?.id == "detail-1"
        }

        let requestedIDs = await repository.requestedIDs
        #expect(requestedIDs.count == 2)
    }
}

extension LaunchDetailViewModelTests {
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

actor MockLaunchDetailRepository: LaunchRepositoryProtocol {
    private(set) var requestedIDs: [String] = []
    private var callCount = 0
    private var handler: (@Sendable (String, Int) async throws -> Launch)?

    func setHandler(_ handler: @escaping @Sendable (String, Int) async throws -> Launch) {
        self.handler = handler
    }

    func fetchUpcomingLaunches(query: LaunchListQuery) async throws -> PagedResult<Launch> {
        PagedResult(items: [])
    }

    func fetchPreviousLaunches(query: LaunchListQuery) async throws -> PagedResult<Launch> {
        PagedResult(items: [])
    }

    func fetchLaunchDetail(id: String) async throws -> Launch {
        requestedIDs.append(id)
        callCount += 1
        guard let handler else {
            throw LaunchError.unknown(underlying: NSError(domain: "MockLaunchDetailRepository", code: 0))
        }
        return try await handler(id, callCount)
    }
}

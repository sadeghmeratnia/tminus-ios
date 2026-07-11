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
            fetchLaunchDetailUseCase: FetchLaunchDetailUseCase(repository: repository),
            fetchRelatedNewsUseCase: FetchRelatedNewsUseCase(repository: MockNewsRepository()))

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
            fetchLaunchDetailUseCase: FetchLaunchDetailUseCase(repository: repository),
            fetchRelatedNewsUseCase: FetchRelatedNewsUseCase(repository: MockNewsRepository()))

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

    @Test("onAppear populates related articles when the repository returns results")
    func onAppearLoadsRelatedNews() async throws {
        let repository = MockLaunchDetailRepository()
        await repository.setHandler { id, _ in
            LaunchDetailViewModelTests.makeLaunch(id: id)
        }
        let article = NewsArticle(
            id: "article-1",
            title: "Related Article",
            summary: "Summary",
            url: URL(string: "https://example.com/article-1")!,
            imageURL: nil,
            newsSite: "SpaceNews",
            publishedAt: Date(timeIntervalSince1970: 1000),
            relatedLaunchIDs: ["detail-1"])
        let newsRepository = MockNewsRepository()
        await newsRepository.setRelatedArticles([article])

        let viewModel = LaunchDetailViewModel(
            launchID: "detail-1",
            fetchLaunchDetailUseCase: FetchLaunchDetailUseCase(repository: repository),
            fetchRelatedNewsUseCase: FetchRelatedNewsUseCase(repository: newsRepository))

        viewModel.onTrigger(.onAppear)
        try await Self.waitUntil {
            viewModel.state.relatedArticles.isEmpty == false
        }

        #expect(viewModel.state.relatedArticles == [article])
        #expect(viewModel.state.phase == .loaded)
    }

    @Test("Related news failure is swallowed and never surfaces an error")
    func relatedNewsFailureIsSwallowed() async throws {
        let repository = MockLaunchDetailRepository()
        await repository.setHandler { id, _ in
            LaunchDetailViewModelTests.makeLaunch(id: id)
        }
        let newsRepository = MockNewsRepository()
        await newsRepository.setShouldThrow(true)

        let viewModel = LaunchDetailViewModel(
            launchID: "detail-1",
            fetchLaunchDetailUseCase: FetchLaunchDetailUseCase(repository: repository),
            fetchRelatedNewsUseCase: FetchRelatedNewsUseCase(repository: newsRepository))

        viewModel.onTrigger(.onAppear)
        try await Self.waitUntil {
            viewModel.state.phase == .loaded
        }
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(viewModel.state.relatedArticles.isEmpty)
        #expect(viewModel.state.phase == .loaded)
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

actor MockNewsRepository: NewsRepositoryProtocol {
    private var relatedArticles: [NewsArticle] = []
    private var shouldThrow = false

    func setRelatedArticles(_ articles: [NewsArticle]) {
        relatedArticles = articles
    }

    func setShouldThrow(_ value: Bool) {
        shouldThrow = value
    }

    func fetchArticles(query: NewsListQuery) async throws -> PagedResult<NewsArticle> {
        PagedResult(items: [])
    }

    func fetchArticleDetail(id: String) async throws -> NewsArticle {
        throw NewsError.unknown(underlying: NSError(domain: "MockNewsRepository", code: 0))
    }

    func fetchRelatedArticles(launchID: String, limit: Int) async throws -> [NewsArticle] {
        if shouldThrow {
            throw NewsError.networkUnavailable
        }
        return relatedArticles
    }
}

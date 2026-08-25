//
//  LaunchDetailViewModelTests.swift
//  TMinusTests
//
//  Created by Sadegh on 28/05/2026.
//

import Foundation
import Testing
@testable import TMinus

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
            fetchRelatedNewsUseCase: FetchRelatedNewsUseCase(relatedNewsProvider: MockNewsRepository())
        )

        viewModel.onTrigger(.onAppear)
        try await waitUntil {
            viewModel.state.phase == .loaded
                && viewModel.state.launch?.id == "detail-1"
        }

        viewModel.onTrigger(.onAppear)
        try await Task.sleep(for: .nanoseconds(50_000_000))

        let requestedIDs = await repository.requestedIDs
        #expect(requestedIDs == ["detail-1"])
    }

    @Test("retry before any failure is a no-op that doesn't touch related news")
    func retryBeforeFailureIsANoOp() async throws {
        let repository = MockLaunchDetailRepository()
        await repository.setHandler { id, _ in
            LaunchDetailViewModelTests.makeLaunch(id: id)
        }
        let newsRepository = MockNewsRepository()
        let viewModel = LaunchDetailViewModel(
            launchID: "detail-1",
            fetchLaunchDetailUseCase: FetchLaunchDetailUseCase(repository: repository),
            fetchRelatedNewsUseCase: FetchRelatedNewsUseCase(relatedNewsProvider: newsRepository)
        )

        // No `.onAppear` yet, phase is still `.idle`, not `.error`, so `.retry` must be a
        // complete no-op: no launch request, and no related-news request either.
        viewModel.onTrigger(.retry)
        try await Task.sleep(for: .nanoseconds(50_000_000))

        #expect(viewModel.state.phase == .idle)
        let requestedIDs = await repository.requestedIDs
        #expect(requestedIDs.isEmpty)
        let relatedRequestCount = await newsRepository.relatedArticlesRequestCount
        #expect(relatedRequestCount == 0)
    }

    @Test("retry reloads after failure")
    func retryReloadsAfterFailure() async throws {
        let repository = MockLaunchDetailRepository()
        await repository.setHandler { id, callIndex in
            if callIndex == 1 {
                throw NetworkFeatureError.networkUnavailable
            }
            return LaunchDetailViewModelTests.makeLaunch(id: id)
        }
        let viewModel = LaunchDetailViewModel(
            launchID: "detail-1",
            fetchLaunchDetailUseCase: FetchLaunchDetailUseCase(repository: repository),
            fetchRelatedNewsUseCase: FetchRelatedNewsUseCase(relatedNewsProvider: MockNewsRepository())
        )

        viewModel.onTrigger(.onAppear)
        try await waitUntil {
            if case .error = viewModel.state.phase { return true }
            return false
        }

        viewModel.onTrigger(.retry)
        try await waitUntil {
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
        let article = try NewsArticle(
            id: "article-1",
            title: "Related Article",
            summary: "Summary",
            url: #require(URL(string: "https://example.com/article-1")),
            imageURL: nil,
            newsSite: "SpaceNews",
            publishedAt: Date(timeIntervalSince1970: 1000),
            relatedLaunchIDs: ["detail-1"]
        )
        let newsRepository = MockNewsRepository()
        await newsRepository.setRelatedArticles([article])

        let viewModel = LaunchDetailViewModel(
            launchID: "detail-1",
            fetchLaunchDetailUseCase: FetchLaunchDetailUseCase(repository: repository),
            fetchRelatedNewsUseCase: FetchRelatedNewsUseCase(relatedNewsProvider: newsRepository)
        )

        viewModel.onTrigger(.onAppear)
        try await waitUntil {
            viewModel.state.relatedArticles.isEmpty == false
        }

        #expect(viewModel.state.relatedArticles == [article])
        #expect(viewModel.state.phase == .loaded)
    }

    @Test("retry re-fetches related news, not just the launch")
    func retryRefetchesRelatedNews() async throws {
        let repository = MockLaunchDetailRepository()
        await repository.setHandler { id, callIndex in
            if callIndex == 1 {
                throw NetworkFeatureError.networkUnavailable
            }
            return LaunchDetailViewModelTests.makeLaunch(id: id)
        }
        let article = try NewsArticle(
            id: "article-1",
            title: "Related Article",
            summary: "Summary",
            url: #require(URL(string: "https://example.com/article-1")),
            imageURL: nil,
            newsSite: "SpaceNews",
            publishedAt: Date(timeIntervalSince1970: 1000),
            relatedLaunchIDs: ["detail-1"]
        )
        let newsRepository = MockNewsRepository()
        await newsRepository.setShouldThrow(true)

        let viewModel = LaunchDetailViewModel(
            launchID: "detail-1",
            fetchLaunchDetailUseCase: FetchLaunchDetailUseCase(repository: repository),
            fetchRelatedNewsUseCase: FetchRelatedNewsUseCase(relatedNewsProvider: newsRepository)
        )

        viewModel.onTrigger(.onAppear)
        try await waitUntil {
            if case .error = viewModel.state.phase { return true }
            return false
        }
        try await waitUntilActor { await newsRepository.relatedArticlesRequestCount == 1 }

        await newsRepository.setShouldThrow(false)
        await newsRepository.setRelatedArticles([article])

        viewModel.onTrigger(.retry)
        try await waitUntil {
            viewModel.state.relatedArticles.isEmpty == false
        }

        #expect(viewModel.state.relatedArticles == [article])
        let requestCount = await newsRepository.relatedArticlesRequestCount
        #expect(requestCount == 2)
    }

    @Test("Refresh uses network-only policy and updates the launch while staying loaded")
    func refreshUpdatesLaunch() async throws {
        let repository = MockLaunchDetailRepository()
        await repository.setHandler { id, callIndex in
            callIndex == 1
                ? LaunchDetailViewModelTests.makeLaunch(id: id)
                : Launch(
                    id: id,
                    name: "Updated \(id)",
                    status: .hold,
                    windowStart: Date(timeIntervalSince1970: 1000),
                    windowEnd: nil,
                    rocket: nil,
                    launchPad: nil,
                    mission: nil,
                    imageURL: nil,
                    webcastURL: nil
                )
        }
        let viewModel = LaunchDetailViewModel(
            launchID: "detail-1",
            fetchLaunchDetailUseCase: FetchLaunchDetailUseCase(repository: repository),
            fetchRelatedNewsUseCase: FetchRelatedNewsUseCase(relatedNewsProvider: MockNewsRepository())
        )

        viewModel.onTrigger(.onAppear)
        try await waitUntil { viewModel.state.phase == .loaded }

        viewModel.onTrigger(.refresh)
        try await waitUntil { viewModel.state.launch?.name == "Updated detail-1" }

        #expect(viewModel.state.phase == .loaded)
        #expect(viewModel.state.refreshError == nil)
        let fetchPolicies = await repository.requestedFetchPolicies
        #expect(fetchPolicies == [.useCache, .networkOnly])
    }

    @Test("A failed refresh keeps the existing launch on screen with a refresh error")
    func failedRefreshKeepsExistingLaunch() async throws {
        let repository = MockLaunchDetailRepository()
        await repository.setHandler { id, callIndex in
            if callIndex == 2 {
                throw NetworkFeatureError.networkUnavailable
            }
            return LaunchDetailViewModelTests.makeLaunch(id: id)
        }
        let viewModel = LaunchDetailViewModel(
            launchID: "detail-1",
            fetchLaunchDetailUseCase: FetchLaunchDetailUseCase(repository: repository),
            fetchRelatedNewsUseCase: FetchRelatedNewsUseCase(relatedNewsProvider: MockNewsRepository())
        )

        viewModel.onTrigger(.onAppear)
        try await waitUntil { viewModel.state.phase == .loaded }

        viewModel.onTrigger(.refresh)
        try await waitUntil { viewModel.state.refreshError != nil }

        #expect(viewModel.state.phase == .loaded)
        #expect(viewModel.state.launch?.id == "detail-1")
    }

    @Test("refresh before the launch has loaded is a no-op that doesn't touch related news")
    func refreshBeforeLoadedIsANoOp() async throws {
        let repository = MockLaunchDetailRepository()
        await repository.setHandler { id, _ in
            LaunchDetailViewModelTests.makeLaunch(id: id)
        }
        let newsRepository = MockNewsRepository()
        let viewModel = LaunchDetailViewModel(
            launchID: "detail-1",
            fetchLaunchDetailUseCase: FetchLaunchDetailUseCase(repository: repository),
            fetchRelatedNewsUseCase: FetchRelatedNewsUseCase(relatedNewsProvider: newsRepository)
        )

        // No `.onAppear` yet, phase is still `.idle`, so `.refresh` must be a complete no-op:
        // no launch request, and no related-news request either (rather than a refresh reloading
        // related news while the main content never even started loading).
        viewModel.onTrigger(.refresh)
        try await Task.sleep(for: .nanoseconds(50_000_000))

        #expect(viewModel.state.phase == .idle)
        let requestedIDs = await repository.requestedIDs
        #expect(requestedIDs.isEmpty)
        let relatedRequestCount = await newsRepository.relatedArticlesRequestCount
        #expect(relatedRequestCount == 0)
    }

    @Test("refresh re-fetches related news with a network-only policy")
    func refreshRefetchesRelatedNewsNetworkOnly() async throws {
        let repository = MockLaunchDetailRepository()
        await repository.setHandler { id, _ in
            LaunchDetailViewModelTests.makeLaunch(id: id)
        }
        let newsRepository = MockNewsRepository()
        let viewModel = LaunchDetailViewModel(
            launchID: "detail-1",
            fetchLaunchDetailUseCase: FetchLaunchDetailUseCase(repository: repository),
            fetchRelatedNewsUseCase: FetchRelatedNewsUseCase(relatedNewsProvider: newsRepository)
        )

        viewModel.onTrigger(.onAppear)
        try await waitUntil { viewModel.state.phase == .loaded }
        try await waitUntilActor { await newsRepository.relatedArticlesRequestCount == 1 }

        viewModel.onTrigger(.refresh)
        try await waitUntilActor { await newsRepository.relatedArticlesRequestCount == 2 }

        let fetchPolicies = await newsRepository.requestedFetchPolicies
        #expect(fetchPolicies == [.useCache, .networkOnly])
    }

    @Test("a failed related-news refresh keeps existing related articles on screen")
    func failedRelatedNewsRefreshKeepsExistingArticles() async throws {
        let repository = MockLaunchDetailRepository()
        await repository.setHandler { id, _ in
            LaunchDetailViewModelTests.makeLaunch(id: id)
        }
        let article = try NewsArticle(
            id: "article-1",
            title: "Related Article",
            summary: "Summary",
            url: #require(URL(string: "https://example.com/article-1")),
            imageURL: nil,
            newsSite: "SpaceNews",
            publishedAt: Date(timeIntervalSince1970: 1000),
            relatedLaunchIDs: ["detail-1"]
        )
        let newsRepository = MockNewsRepository()
        await newsRepository.setRelatedArticles([article])

        let viewModel = LaunchDetailViewModel(
            launchID: "detail-1",
            fetchLaunchDetailUseCase: FetchLaunchDetailUseCase(repository: repository),
            fetchRelatedNewsUseCase: FetchRelatedNewsUseCase(relatedNewsProvider: newsRepository)
        )

        viewModel.onTrigger(.onAppear)
        try await waitUntil { viewModel.state.relatedArticles.isEmpty == false }

        await newsRepository.setShouldThrow(true)
        viewModel.onTrigger(.refresh)
        try await waitUntilActor { await newsRepository.relatedArticlesRequestCount == 2 }
        try await Task.sleep(for: .nanoseconds(50_000_000))

        #expect(viewModel.state.relatedArticles == [article])
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
            fetchRelatedNewsUseCase: FetchRelatedNewsUseCase(relatedNewsProvider: newsRepository)
        )

        viewModel.onTrigger(.onAppear)
        try await waitUntil {
            viewModel.state.phase == .loaded
        }
        try await Task.sleep(for: .nanoseconds(50_000_000))

        #expect(viewModel.state.relatedArticles.isEmpty)
        #expect(viewModel.state.phase == .loaded)
    }
}

private extension LaunchDetailViewModelTests {
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

actor MockLaunchDetailRepository: LaunchRepositoryProtocol {
    private(set) var requestedIDs: [String] = []
    private(set) var requestedFetchPolicies: [FetchPolicy] = []
    private var callCount = 0
    private var handler: (@Sendable (String, Int) async throws -> Launch)?

    func setHandler(_ handler: @escaping @Sendable (String, Int) async throws -> Launch) {
        self.handler = handler
    }

    func fetchUpcomingLaunches(query _: LaunchListQuery) async throws -> PagedResult<Launch> {
        PagedResult(items: [])
    }

    func fetchPreviousLaunches(query _: LaunchListQuery) async throws -> PagedResult<Launch> {
        PagedResult(items: [])
    }

    func fetchLaunchDetail(id: String, fetchPolicy: FetchPolicy) async throws -> Launch {
        requestedIDs.append(id)
        requestedFetchPolicies.append(fetchPolicy)
        callCount += 1
        guard let handler else {
            throw NetworkFeatureError.unknown(underlying: ErrorSummary(NSError(domain: "MockLaunchDetailRepository", code: 0)))
        }
        return try await handler(id, callCount)
    }
}

actor MockNewsRepository: NewsRepositoryProtocol {
    private(set) var relatedArticlesRequestCount = 0
    private(set) var requestedFetchPolicies: [FetchPolicy] = []
    private var relatedArticles: [NewsArticle] = []
    private var shouldThrow = false
    private var handler: (@Sendable (Int) async throws -> [NewsArticle])?

    func setRelatedArticles(_ articles: [NewsArticle]) {
        relatedArticles = articles
    }

    func setShouldThrow(_ value: Bool) {
        shouldThrow = value
    }

    /// Overrides the plain `relatedArticles`/`shouldThrow` behavior with a per-call-count async
    /// closure, so a test can make an earlier call resolve *after* a later one, e.g. to prove a
    /// stale related-news response can't clobber a newer one once it's applied.
    func setHandler(_ handler: @escaping @Sendable (Int) async throws -> [NewsArticle]) {
        self.handler = handler
    }

    func fetchArticles(query _: NewsListQuery) async throws -> PagedResult<NewsArticle> {
        PagedResult(items: [])
    }

    func fetchArticleDetail(id _: String, fetchPolicy _: FetchPolicy) async throws -> NewsArticle {
        throw NetworkFeatureError.unknown(underlying: ErrorSummary(NSError(domain: "MockNewsRepository", code: 0)))
    }

    func fetchRelatedArticles(launchID _: String, limit _: Int, fetchPolicy: FetchPolicy) async throws -> [NewsArticle] {
        relatedArticlesRequestCount += 1
        requestedFetchPolicies.append(fetchPolicy)
        if let handler {
            return try await handler(relatedArticlesRequestCount)
        }
        if shouldThrow {
            throw NetworkFeatureError.networkUnavailable
        }
        return relatedArticles
    }
}

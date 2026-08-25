//
//  NewsDetailViewModelTests.swift
//  TMinusTests
//
//  Created by Sadegh on 09/07/2026.
//

import Foundation
import Testing
@testable import TMinus

@MainActor
@Suite("NewsDetailViewModel")
struct NewsDetailViewModelTests {
    @Test("onAppear loads article detail once")
    func onAppearLoadsOnce() async throws {
        let repository = MockNewsDetailRepository()
        await repository.setHandler { id, _ in
            NewsDetailViewModelTests.makeArticle(id: id)
        }
        let viewModel = NewsDetailViewModel(
            articleID: "detail-1",
            fetchNewsArticleDetailUseCase: FetchNewsArticleDetailUseCase(repository: repository)
        )

        viewModel.onTrigger(.onAppear)
        try await waitUntil {
            viewModel.state.phase == .loaded && viewModel.state.article?.id == "detail-1"
        }

        viewModel.onTrigger(.onAppear)
        try await Task.sleep(for: .nanoseconds(50_000_000))

        let requestedIDs = await repository.requestedIDs
        #expect(requestedIDs == ["detail-1"])
    }

    @Test("retry before any failure is a no-op")
    func retryBeforeFailureIsANoOp() async throws {
        let repository = MockNewsDetailRepository()
        await repository.setHandler { id, _ in
            NewsDetailViewModelTests.makeArticle(id: id)
        }
        let viewModel = NewsDetailViewModel(
            articleID: "detail-1",
            fetchNewsArticleDetailUseCase: FetchNewsArticleDetailUseCase(repository: repository)
        )

        // No `.onAppear` yet, phase is still `.idle`, not `.error`, so `.retry` must be a
        // complete no-op.
        viewModel.onTrigger(.retry)
        try await Task.sleep(for: .nanoseconds(50_000_000))

        #expect(viewModel.state.phase == .idle)
        let requestedIDs = await repository.requestedIDs
        #expect(requestedIDs.isEmpty)
    }

    @Test("retry reloads after failure")
    func retryReloadsAfterFailure() async throws {
        let repository = MockNewsDetailRepository()
        await repository.setHandler { id, callIndex in
            if callIndex == 1 {
                throw NetworkFeatureError.networkUnavailable
            }
            return NewsDetailViewModelTests.makeArticle(id: id)
        }
        let viewModel = NewsDetailViewModel(
            articleID: "detail-1",
            fetchNewsArticleDetailUseCase: FetchNewsArticleDetailUseCase(repository: repository)
        )

        viewModel.onTrigger(.onAppear)
        try await waitUntil {
            if case .error = viewModel.state.phase { return true }
            return false
        }

        viewModel.onTrigger(.retry)
        try await waitUntil {
            viewModel.state.phase == .loaded && viewModel.state.article?.id == "detail-1"
        }

        let requestedIDs = await repository.requestedIDs
        #expect(requestedIDs.count == 2)
    }

    @Test("refresh before the article has loaded is a no-op")
    func refreshBeforeLoadedIsANoOp() async throws {
        let repository = MockNewsDetailRepository()
        await repository.setHandler { id, _ in
            NewsDetailViewModelTests.makeArticle(id: id)
        }
        let viewModel = NewsDetailViewModel(
            articleID: "detail-1",
            fetchNewsArticleDetailUseCase: FetchNewsArticleDetailUseCase(repository: repository)
        )

        // No `.onAppear` yet, phase is still `.idle`, not `.loaded`, so `.refresh` must be a
        // complete no-op.
        viewModel.onTrigger(.refresh)
        try await Task.sleep(for: .nanoseconds(50_000_000))

        #expect(viewModel.state.phase == .idle)
        let requestedIDs = await repository.requestedIDs
        #expect(requestedIDs.isEmpty)
    }

    @Test("Refresh uses network-only policy and updates the article while staying loaded")
    func refreshUpdatesArticle() async throws {
        let repository = MockNewsDetailRepository()
        await repository.setHandler { id, callIndex in
            callIndex == 1
                ? NewsDetailViewModelTests.makeArticle(id: id)
                : NewsArticle(
                    id: id,
                    title: "Updated \(id)",
                    summary: "Updated summary",
                    url: URL(string: "https://example.com/\(id)")!,
                    imageURL: nil,
                    newsSite: "SpaceNews",
                    publishedAt: Date(timeIntervalSince1970: 1000),
                    relatedLaunchIDs: []
                )
        }
        let viewModel = NewsDetailViewModel(
            articleID: "detail-1",
            fetchNewsArticleDetailUseCase: FetchNewsArticleDetailUseCase(repository: repository)
        )

        viewModel.onTrigger(.onAppear)
        try await waitUntil { viewModel.state.phase == .loaded }

        viewModel.onTrigger(.refresh)
        try await waitUntil { viewModel.state.article?.title == "Updated detail-1" }

        #expect(viewModel.state.phase == .loaded)
        #expect(viewModel.state.refreshError == nil)
        let fetchPolicies = await repository.requestedFetchPolicies
        #expect(fetchPolicies == [.useCache, .networkOnly])
    }

    @Test("A failed refresh keeps the existing article on screen with a refresh error")
    func failedRefreshKeepsExistingArticle() async throws {
        let repository = MockNewsDetailRepository()
        await repository.setHandler { id, callIndex in
            if callIndex == 2 {
                throw NetworkFeatureError.networkUnavailable
            }
            return NewsDetailViewModelTests.makeArticle(id: id)
        }
        let viewModel = NewsDetailViewModel(
            articleID: "detail-1",
            fetchNewsArticleDetailUseCase: FetchNewsArticleDetailUseCase(repository: repository)
        )

        viewModel.onTrigger(.onAppear)
        try await waitUntil { viewModel.state.phase == .loaded }

        viewModel.onTrigger(.refresh)
        try await waitUntil { viewModel.state.refreshError != nil }

        #expect(viewModel.state.phase == .loaded)
        #expect(viewModel.state.article?.id == "detail-1")
    }
}

private extension NewsDetailViewModelTests {
    nonisolated static func makeArticle(id: String) -> NewsArticle {
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

actor MockNewsDetailRepository: NewsRepositoryProtocol {
    private(set) var requestedIDs: [String] = []
    private(set) var requestedFetchPolicies: [FetchPolicy] = []
    private var callCount = 0
    private var handler: (@Sendable (String, Int) async throws -> NewsArticle)?

    func setHandler(_ handler: @escaping @Sendable (String, Int) async throws -> NewsArticle) {
        self.handler = handler
    }

    func fetchArticles(query _: NewsListQuery) async throws -> PagedResult<NewsArticle> {
        PagedResult(items: [])
    }

    func fetchArticleDetail(id: String, fetchPolicy: FetchPolicy) async throws -> NewsArticle {
        requestedIDs.append(id)
        requestedFetchPolicies.append(fetchPolicy)
        callCount += 1
        guard let handler else {
            throw NetworkFeatureError.unknown(underlying: ErrorSummary(NSError(domain: "MockNewsDetailRepository", code: 0)))
        }
        return try await handler(id, callCount)
    }

    func fetchRelatedArticles(launchID _: String, limit _: Int, fetchPolicy _: FetchPolicy) async throws -> [NewsArticle] {
        []
    }
}

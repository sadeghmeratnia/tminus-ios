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
        try await Self.waitUntil {
            viewModel.state.phase == .loaded && viewModel.state.article?.id == "detail-1"
        }

        viewModel.onTrigger(.onAppear)
        try await Task.sleep(for: .nanoseconds(50_000_000))

        let requestedIDs = await repository.requestedIDs
        #expect(requestedIDs == ["detail-1"])
    }

    @Test("retry reloads after failure")
    func retryReloadsAfterFailure() async throws {
        let repository = MockNewsDetailRepository()
        await repository.setHandler { id, callIndex in
            if callIndex == 1 {
                throw NewsError.networkUnavailable
            }
            return NewsDetailViewModelTests.makeArticle(id: id)
        }
        let viewModel = NewsDetailViewModel(
            articleID: "detail-1",
            fetchNewsArticleDetailUseCase: FetchNewsArticleDetailUseCase(repository: repository)
        )

        viewModel.onTrigger(.onAppear)
        try await Self.waitUntil {
            if case .error = viewModel.state.phase { return true }
            return false
        }

        viewModel.onTrigger(.retry)
        try await Self.waitUntil {
            viewModel.state.phase == .loaded && viewModel.state.article?.id == "detail-1"
        }

        let requestedIDs = await repository.requestedIDs
        #expect(requestedIDs.count == 2)
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

    static func waitUntil(timeoutNanoseconds: UInt64 = 1_500_000_000,
                          checkEveryNanoseconds: UInt64 = 20_000_000,
                          _ condition: @escaping @MainActor () -> Bool) async throws
    {
        let start = DispatchTime.now().uptimeNanoseconds
        while DispatchTime.now().uptimeNanoseconds - start < timeoutNanoseconds {
            if await condition() { return }
            try await Task.sleep(for: .nanoseconds(checkEveryNanoseconds))
        }
        Issue.record("Timed out waiting for expected state")
    }
}

actor MockNewsDetailRepository: NewsRepositoryProtocol {
    private(set) var requestedIDs: [String] = []
    private var callCount = 0
    private var handler: (@Sendable (String, Int) async throws -> NewsArticle)?

    func setHandler(_ handler: @escaping @Sendable (String, Int) async throws -> NewsArticle) {
        self.handler = handler
    }

    func fetchArticles(query _: NewsListQuery) async throws -> PagedResult<NewsArticle> {
        PagedResult(items: [])
    }

    func fetchArticleDetail(id: String) async throws -> NewsArticle {
        requestedIDs.append(id)
        callCount += 1
        guard let handler else {
            throw NewsError.unknown(underlying: ErrorSummary(NSError(domain: "MockNewsDetailRepository", code: 0)))
        }
        return try await handler(id, callCount)
    }

    func fetchRelatedArticles(launchID _: String, limit _: Int) async throws -> [NewsArticle] {
        []
    }
}

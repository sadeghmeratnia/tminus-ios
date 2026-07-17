//
//  NewsCoordinatorTests.swift
//  TMinusTests
//
//  Created by Sadegh on 13/07/2026.
//

@testable import TMinus
import Testing
import Foundation
import SwiftUI

@MainActor
@Suite("NewsCoordinator")
struct NewsCoordinatorTests {
    @Test("Path starts empty")
    func pathStartsEmpty() {
        let coordinator = Self.makeCoordinator()
        #expect(coordinator.path.isEmpty)
    }

    @Test("showArticleDetail pushes a destination onto the path")
    func showArticleDetailPushesDestination() {
        let coordinator = Self.makeCoordinator()

        coordinator.showArticleDetail(id: "article-1")

        #expect(coordinator.path.count == 1)
    }

    @Test("Repeated navigation accumulates distinct path entries")
    func repeatedNavigationAccumulatesPathEntries() {
        let coordinator = Self.makeCoordinator()

        coordinator.showArticleDetail(id: "article-1")
        coordinator.showArticleDetail(id: "article-2")

        #expect(coordinator.path.count == 2)
    }

    @Test("destinationView resolves an articleDetail destination via the injected builder")
    func destinationViewResolvesArticleDetail() {
        let detailBuilder = RecordingNewsDetailBuilder()
        let coordinator = NewsCoordinator(
            newsListBuilder: Self.makeListBuilder(),
            newsDetailBuilder: detailBuilder)

        _ = coordinator.destinationView(for: .articleDetail(id: "article-42"))

        #expect(detailBuilder.requestedArticleIDs == ["article-42"])
    }

    @Test("makeRootView builds a NewsRootView backed by this coordinator")
    func makeRootViewBuildsRootView() {
        let coordinator = Self.makeCoordinator()
        _ = coordinator.makeRootView()
        #expect(coordinator.path.isEmpty)
    }
}

extension NewsCoordinatorTests {
    fileprivate static func makeCoordinator() -> NewsCoordinator {
        NewsCoordinator(newsListBuilder: makeListBuilder(), newsDetailBuilder: makeDetailBuilder())
    }

    fileprivate static func makeListBuilder() -> NewsListBuilder {
        NewsListBuilder(
            viewModel: NewsListViewModel(fetchNewsArticlesUseCase: FetchNewsArticlesUseCase(repository: MockNewsListRepository())))
    }

    fileprivate static func makeDetailBuilder() -> NewsDetailBuilder {
        NewsDetailBuilder(
            fetchNewsArticleDetailUseCase: FetchNewsArticleDetailUseCase(repository: MockNewsDetailRepository()))
    }
}

// MARK: - RecordingNewsDetailBuilder

@MainActor
private final class RecordingNewsDetailBuilder: NewsDetailBuilding {
    private(set) var requestedArticleIDs: [String] = []

    func makeView(articleID: String) -> DefaultNewsDetailView {
        requestedArticleIDs.append(articleID)
        return NewsDetailBuilder(
            fetchNewsArticleDetailUseCase: FetchNewsArticleDetailUseCase(repository: MockNewsDetailRepository()))
            .makeView(articleID: articleID)
    }
}

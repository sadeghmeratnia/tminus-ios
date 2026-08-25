//
//  NewsListViewModelTests.swift
//  TMinusTests
//
//  Created by Sadegh on 09/07/2026.
//

import Foundation
import Testing
@testable import TMinus

@MainActor
@Suite("NewsListViewModel")
struct NewsListViewModelTests {
    @Test("onAppear loads articles only once")
    func onAppearLoadsOnce() async throws {
        let repository = MockNewsListRepository()
        await repository.setHandler { _, _ in
            PagedResult(items: [Self.makeArticle(id: "1")])
        }
        let viewModel = Self.makeViewModel(repository: repository)

        viewModel.onTrigger(.onAppear)
        try await waitUntil {
            viewModel.state.phase == .loaded && viewModel.state.articles.map(\.id) == ["1"]
        }

        viewModel.onTrigger(.onAppear)
        try await Task.sleep(for: .nanoseconds(50_000_000))

        let queries = await repository.queries
        #expect(queries.count == 1)
        #expect(queries.first?.fetchPolicy == .useCache)
    }

    @Test("refresh bypasses cache and keeps previous articles while loading")
    func refreshBypassesCache() async throws {
        let repository = MockNewsListRepository()
        await repository.setHandler { query, _ in
            if query.fetchPolicy == .networkOnly {
                return PagedResult(items: [Self.makeArticle(id: "fresh")])
            }
            return PagedResult(items: [Self.makeArticle(id: "cached")])
        }
        let viewModel = Self.makeViewModel(repository: repository)

        viewModel.onTrigger(.onAppear)
        try await waitUntil {
            viewModel.state.phase == .loaded && viewModel.state.articles.map(\.id) == ["cached"]
        }

        viewModel.onTrigger(.refresh)
        #expect(viewModel.state.phase == .loading(.refresh))
        #expect(viewModel.state.articles.map(\.id) == ["cached"])

        try await waitUntil {
            viewModel.state.phase == .loaded && viewModel.state.articles.map(\.id) == ["fresh"]
        }
    }

    @Test("search text change debounces before triggering a load")
    func searchDebounces() async throws {
        let repository = MockNewsListRepository()
        await repository.setHandler { query, _ in
            PagedResult(items: [Self.makeArticle(id: query.searchText ?? "none")])
        }
        let viewModel = Self.makeViewModel(repository: repository)

        viewModel.onTrigger(.onAppear)
        try await waitUntil { viewModel.state.phase == .loaded }

        viewModel.onTrigger(.searchTextChanged("m"))
        viewModel.onTrigger(.searchTextChanged("mo"))
        viewModel.onTrigger(.searchTextChanged("moon"))

        // Immediately after typing, the search text is reflected but no load has fired yet.
        #expect(viewModel.state.searchText == "moon")
        try await Task.sleep(for: .nanoseconds(100_000_000))
        let queriesRightAfterTyping = await repository.queries
        #expect(queriesRightAfterTyping.count == 1, "Only the initial appear load should have fired so far")

        try await waitUntil {
            viewModel.state.phase == .loaded && viewModel.state.articles.map(\.id) == ["moon"]
        }

        let queries = await repository.queries
        #expect(queries.map(\.searchText).last == "moon")
        #expect(queries.filter { $0.searchText == "m" || $0.searchText == "mo" }.isEmpty, "Intermediate keystrokes must not trigger loads")
    }

    @Test("retyping a search that's already loaded does not trigger a redundant load")
    func searchSkipsRedundantReloadForAlreadyLoadedText() async throws {
        let repository = MockNewsListRepository()
        await repository.setHandler { query, _ in
            PagedResult(items: [Self.makeArticle(id: query.searchText ?? "none")])
        }
        let viewModel = Self.makeViewModel(repository: repository)

        viewModel.onTrigger(.onAppear)
        try await waitUntil { viewModel.state.phase == .loaded }

        viewModel.onTrigger(.searchTextChanged("moon"))
        try await waitUntil {
            viewModel.state.phase == .loaded && viewModel.state.articles.map(\.id) == ["moon"]
        }
        let queriesAfterFirstSearch = await repository.queries

        // Typing away and back to the exact text that's already loaded must not clear the
        // currently-displayed results or issue another network call for it.
        viewModel.onTrigger(.searchTextChanged("moons"))
        viewModel.onTrigger(.searchTextChanged("moon"))
        try await Task.sleep(for: .milliseconds(600))

        #expect(viewModel.state.phase == .loaded)
        #expect(viewModel.state.articles.map(\.id) == ["moon"])
        let queriesAfterRetyping = await repository.queries
        #expect(queriesAfterRetyping.count == queriesAfterFirstSearch.count, "No new query should have been issued")
    }

    @Test("retyping a search that previously failed triggers a retry")
    func searchRetriesAfterPreviousFailure() async throws {
        let repository = MockNewsListRepository()
        await repository.setHandler { query, callCount in
            if query.searchText == "moon", callCount == 2 {
                throw NSError(domain: "MockNewsListRepository", code: 500)
            }
            return PagedResult(items: [Self.makeArticle(id: query.searchText ?? "none")])
        }
        let viewModel = Self.makeViewModel(repository: repository)

        viewModel.onTrigger(.onAppear)
        try await waitUntil { viewModel.state.phase == .loaded }

        viewModel.onTrigger(.searchTextChanged("moon"))
        try await waitUntil {
            if case .error = viewModel.state.phase { return true }
            return false
        }

        // Retyping the exact same text that just failed must re-dispatch the search rather
        // than being silently swallowed as "already loaded".
        viewModel.onTrigger(.searchTextChanged("moon"))
        try await waitUntil {
            viewModel.state.phase == .loaded && viewModel.state.articles.map(\.id) == ["moon"]
        }

        let queries = await repository.queries
        #expect(queries.filter { $0.searchText == "moon" }.count == 2, "The failed search must have been retried")
    }

    @Test("last article appearance triggers paginated prefetch")
    func articleAppearancePrefetchesNextPage() async throws {
        let repository = MockNewsListRepository()
        await repository.setHandler { query, _ in
            if query.page == 1 {
                return PagedResult(
                    items: [Self.makeArticle(id: "page-1-last")],
                    currentPage: 1,
                    totalCount: 2,
                    nextPage: 2,
                    previousPage: nil
                )
            }
            return PagedResult(
                items: [Self.makeArticle(id: "page-2-item")],
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
                && viewModel.state.articles.map(\.id) == ["page-1-last"]
                && viewModel.state.pagination.nextPage == 2
        }

        viewModel.onTrigger(.articleAppeared("page-1-last"))

        try await waitUntil {
            viewModel.state.phase == .loaded
                && viewModel.state.articles.map(\.id) == ["page-1-last", "page-2-item"]
        }
    }
}

private extension NewsListViewModelTests {
    static func makeViewModel(repository: NewsRepositoryProtocol) -> NewsListViewModel {
        NewsListViewModel(fetchNewsArticlesUseCase: FetchNewsArticlesUseCase(repository: repository))
    }

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

// MARK: - MockNewsListRepository

actor MockNewsListRepository: NewsRepositoryProtocol {
    private(set) var queries: [NewsListQuery] = []
    private var callCount = 0
    private var handler: (@Sendable (NewsListQuery, Int) async throws -> PagedResult<NewsArticle>)?

    func setHandler(_ handler: @escaping @Sendable (NewsListQuery, Int) async throws -> PagedResult<NewsArticle>) {
        self.handler = handler
    }

    func fetchArticles(query: NewsListQuery) async throws -> PagedResult<NewsArticle> {
        callCount += 1
        queries.append(query)
        guard let handler else { return PagedResult(items: []) }
        return try await handler(query, callCount)
    }

    func fetchArticleDetail(id _: String, fetchPolicy _: FetchPolicy) async throws -> NewsArticle {
        throw NSError(domain: "MockNewsListRepository", code: 404)
    }

    func fetchRelatedArticles(launchID _: String, limit _: Int, fetchPolicy _: FetchPolicy) async throws -> [NewsArticle] {
        []
    }
}

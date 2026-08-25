//
//  NewsRepositoryTests.swift
//  TMinusTests
//
//  Created by Sadegh on 09/07/2026.
//

import Foundation
import Testing
@testable import TMinus

@Suite("NewsRepository")
enum NewsRepositoryTests {
    @Test("Articles list maps response and pagination from the remote data source")
    static func fetchArticles() async throws {
        let dataSource = MockNewsRemoteDataSource()
        dataSource.articlesResponse = NewsResponseDTO(
            count: 1,
            next: "https://api.spaceflightnewsapi.net/v4/articles/?limit=20&offset=40",
            previous: "https://api.spaceflightnewsapi.net/v4/articles/?limit=20&offset=0",
            results: [Self.makeArticleDTO(id: 1)]
        )
        let repository = NewsRepository(remoteDataSource: dataSource, localDataSource: MockNewsLocalDataSource())
        let query = NewsListQuery(page: 2, limit: 20, searchText: "starship", fetchPolicy: .networkOnly)

        let page = try await repository.fetchArticles(query: query)

        #expect(page.items.count == 1)
        #expect(page.items.first?.id == "1")
        #expect(page.currentPage == 2)
        #expect(page.totalCount == 1)
        #expect(page.nextPage == 3)
        #expect(page.previousPage == 1)
        #expect(dataSource.lastArticlesQuery == query)
    }

    @Test("Articles with no usable URL are dropped from the page")
    static func dropsArticlesWithoutURL() async throws {
        let dataSource = MockNewsRemoteDataSource()
        dataSource.articlesResponse = NewsResponseDTO(
            count: 2,
            next: nil,
            previous: nil,
            results: [Self.makeArticleDTO(id: 1), Self.makeArticleDTO(id: 2, url: "")]
        )
        let repository = NewsRepository(remoteDataSource: dataSource, localDataSource: MockNewsLocalDataSource())

        let page = try await repository.fetchArticles(query: NewsListQuery(fetchPolicy: .networkOnly))

        #expect(page.items.map(\.id) == ["1"])
    }

    @Test("Article detail maps a single article")
    static func fetchArticleDetail() async throws {
        let dataSource = MockNewsRemoteDataSource()
        dataSource.detailResponse = Self.makeArticleDTO(id: 7)
        let repository = NewsRepository(remoteDataSource: dataSource, localDataSource: MockNewsLocalDataSource())

        let article = try await repository.fetchArticleDetail(id: "7", fetchPolicy: .useCache)

        #expect(article.id == "7")
        #expect(dataSource.lastDetailRequest?.id == "7")
        #expect(dataSource.lastDetailRequest?.fetchPolicy == .useCache)
    }

    @Test("Article detail with network-only policy bypasses the cache")
    static func fetchArticleDetailBypassesCacheWithNetworkOnlyPolicy() async throws {
        let dataSource = MockNewsRemoteDataSource()
        dataSource.detailResponse = Self.makeArticleDTO(id: 7)
        let localDataSource = MockNewsLocalDataSource()
        await localDataSource.setDetail(Self.makeArticle(id: "cached-1"))
        let repository = NewsRepository(remoteDataSource: dataSource, localDataSource: localDataSource)

        let article = try await repository.fetchArticleDetail(id: "7", fetchPolicy: .networkOnly)

        #expect(article.id == "7")
        #expect(dataSource.lastDetailRequest?.fetchPolicy == .networkOnly)
        let maxAges = await localDataSource.detailMaxAges
        #expect(maxAges.isEmpty, "A network-only refresh must not consult the cache first")
    }

    @Test("Article detail throws decodingFailed when the article has no usable URL")
    static func articleDetailThrowsForUnmappableArticle() async throws {
        let dataSource = MockNewsRemoteDataSource()
        dataSource.detailResponse = Self.makeArticleDTO(id: 8, url: "")
        let repository = NewsRepository(remoteDataSource: dataSource, localDataSource: MockNewsLocalDataSource())

        await #expect(throws: NetworkFeatureError.self) {
            try await repository.fetchArticleDetail(id: "8", fetchPolicy: .useCache)
        }
    }

    @Test("Falls back to stale local cache when the fresh response fails to decode")
    static func fallsBackToStaleDetailWhenFreshResponseFailsToDecode() async throws {
        let dataSource = MockNewsRemoteDataSource()
        dataSource.detailResponse = Self.makeArticleDTO(id: 8, url: "")
        let localDataSource = MockNewsLocalDataSource()
        // Stale-only: the primary cache check must miss so the remote fetch (which will fail to
        // decode) actually runs, then the fallback read is what saves it.
        await localDataSource.setStaleDetail(Self.makeArticle(id: "cached-1"))
        let repository = NewsRepository(remoteDataSource: dataSource, localDataSource: localDataSource)

        // A decode failure must get the same stale-cache safety net as a network failure,
        // previously it short-circuited past the fallback entirely.
        let article = try await repository.fetchArticleDetail(id: "cached-1", fetchPolicy: .useCache)

        #expect(article.id == "cached-1")
    }

    @Test("Falls back to stale local cache when a use-cache detail fetch fails")
    static func fallsBackToStaleDetailWhenUseCacheFetchFails() async throws {
        let dataSource = MockNewsRemoteDataSource()
        dataSource.detailError = NetworkError.transport(URLError(.notConnectedToInternet))
        let localDataSource = MockNewsLocalDataSource()
        // Stale-only, so this genuinely exercises "primary cache misses, remote fails, fallback
        // saves it" rather than trivially succeeding via the primary cache check alone.
        await localDataSource.setStaleDetail(Self.makeArticle(id: "cached-1"))
        let repository = NewsRepository(remoteDataSource: dataSource, localDataSource: localDataSource)

        let article = try await repository.fetchArticleDetail(id: "cached-1", fetchPolicy: .useCache)

        #expect(article.id == "cached-1")
    }

    @Test("Network-only detail refresh does NOT fall back to stale cache on failure")
    static func networkOnlyDetailRefreshDoesNotFallBackOnFailure() async throws {
        let dataSource = MockNewsRemoteDataSource()
        dataSource.detailError = NetworkError.transport(URLError(.notConnectedToInternet))
        let localDataSource = MockNewsLocalDataSource()
        await localDataSource.setStaleDetail(Self.makeArticle(id: "cached-1"))
        let repository = NewsRepository(remoteDataSource: dataSource, localDataSource: localDataSource)

        await #expect(throws: NetworkFeatureError.self) {
            try await repository.fetchArticleDetail(id: "cached-1", fetchPolicy: .networkOnly)
        }
    }

    @Test("Related articles are fetched by launch id and compact-mapped")
    static func fetchRelatedArticles() async throws {
        let dataSource = MockNewsRemoteDataSource()
        dataSource.relatedResponse = NewsResponseDTO(
            count: 1,
            next: nil,
            previous: nil,
            results: [Self.makeArticleDTO(id: 9)]
        )
        let repository = NewsRepository(remoteDataSource: dataSource, localDataSource: MockNewsLocalDataSource())

        let articles = try await repository.fetchRelatedArticles(launchID: "launch-1", limit: 5, fetchPolicy: .networkOnly)

        #expect(articles.map(\.id) == ["9"])
        #expect(dataSource.lastRelatedRequest?.launchID == "launch-1")
        #expect(dataSource.lastRelatedRequest?.limit == 5)
    }

    @Test("Transport failures are mapped to networkUnavailable")
    static func mapsTransportErrors() async throws {
        let dataSource = MockNewsRemoteDataSource()
        dataSource.articlesError = NetworkError.transport(URLError(.notConnectedToInternet))
        let repository = NewsRepository(remoteDataSource: dataSource, localDataSource: MockNewsLocalDataSource())

        await #expect(throws: NetworkFeatureError.self) {
            try await repository.fetchArticles(query: NewsListQuery(fetchPolicy: .networkOnly))
        }
    }

    @Test("Uses local cache first for a use-cache articles fetch")
    static func usesLocalCacheFirstForArticles() async throws {
        let dataSource = MockNewsRemoteDataSource()
        let localDataSource = MockNewsLocalDataSource()
        await localDataSource.setArticles([Self.makeArticle(id: "local-1")])
        let repository = NewsRepository(remoteDataSource: dataSource, localDataSource: localDataSource)

        let page = try await repository.fetchArticles(query: NewsListQuery(fetchPolicy: .useCache))

        #expect(page.items.map(\.id) == ["local-1"])
        #expect(dataSource.lastArticlesQuery == nil)
    }

    @Test("Falls back to stale local cache when a use-cache articles fetch fails")
    static func fallsBackToStaleArticlesWhenUseCacheFetchFails() async throws {
        let dataSource = MockNewsRemoteDataSource()
        dataSource.articlesError = NetworkError.transport(URLError(.notConnectedToInternet))
        let localDataSource = MockNewsLocalDataSource()
        await localDataSource.setStaleArticles([Self.makeArticle(id: "stale-1")])
        let repository = NewsRepository(remoteDataSource: dataSource, localDataSource: localDataSource)

        let page = try await repository.fetchArticles(query: NewsListQuery(fetchPolicy: .useCache))

        #expect(page.items.map(\.id) == ["stale-1"])
    }
}

private extension NewsRepositoryTests {
    static func makeArticleDTO(id: Int, url: String? = nil) -> NewsArticleDTO {
        let json = """
        {
          "id": \(id),
          "title": "Mission \(id)",
          "summary": "Summary",
          "url": "\(url ?? "https://example.com/\(id)")",
          "image_url": null,
          "news_site": "SpaceNews",
          "published_at": "2026-05-12T10:00:00Z",
          "launches": []
        }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try! decoder.decode(NewsArticleDTO.self, from: Data(json.utf8))
    }

    static func makeArticle(id: String) -> NewsArticle {
        NewsArticle(
            id: id,
            title: "Cached Article",
            summary: "Summary",
            url: URL(string: "https://example.com/\(id)")!,
            imageURL: nil,
            newsSite: "SpaceNews",
            publishedAt: Date(timeIntervalSince1970: 1000),
            relatedLaunchIDs: []
        )
    }
}

// `nonisolated(unsafe)` on every stored property: this mock is configured synchronously before
// each test's sequential `await` calls exercise it, never touched from two tasks at once, the
// same rationale as the local `nonisolated(unsafe) var` counters elsewhere in this test target,
// just at the property level since `NewsRemoteDataSource: Sendable` requires this class to
// conform too.
private final class MockNewsRemoteDataSource: NewsRemoteDataSource {
    nonisolated(unsafe) var articlesResponse = NewsResponseDTO(count: nil, next: nil, previous: nil, results: [])
    nonisolated(unsafe) var detailResponse = NewsRepositoryTests.makeArticleDTO(id: 0)
    nonisolated(unsafe) var relatedResponse = NewsResponseDTO(count: nil, next: nil, previous: nil, results: [])
    nonisolated(unsafe) var lastArticlesQuery: NewsListQuery?
    nonisolated(unsafe) var lastDetailRequest: (id: String, fetchPolicy: FetchPolicy)?
    nonisolated(unsafe) var lastRelatedRequest: (launchID: String, limit: Int, fetchPolicy: FetchPolicy)?
    nonisolated(unsafe) var articlesError: Error?
    nonisolated(unsafe) var detailError: Error?
    nonisolated(unsafe) var relatedError: Error?

    func fetchArticles(query: NewsListQuery) async throws -> NewsResponseDTO {
        if let articlesError { throw articlesError }
        lastArticlesQuery = query
        return articlesResponse
    }

    func fetchArticleDetail(id: String, fetchPolicy: FetchPolicy) async throws -> NewsArticleDTO {
        if let detailError { throw detailError }
        lastDetailRequest = (id, fetchPolicy)
        return detailResponse
    }

    func fetchRelatedArticles(launchID: String, limit: Int, fetchPolicy: FetchPolicy) async throws -> NewsResponseDTO {
        if let relatedError { throw relatedError }
        lastRelatedRequest = (launchID, limit, fetchPolicy)
        return relatedResponse
    }
}

// MARK: - MockNewsLocalDataSource

private actor MockNewsLocalDataSource: NewsLocalDataSource {
    private var articles: [NewsArticle] = []
    private var staleArticles: [NewsArticle] = []
    private var detail: NewsArticle?
    private var staleDetail: NewsArticle?
    private(set) var detailMaxAges: [TimeInterval?] = []

    func setArticles(_ articles: [NewsArticle]) {
        self.articles = articles
    }

    func setStaleArticles(_ articles: [NewsArticle]) {
        staleArticles = articles
    }

    func setDetail(_ article: NewsArticle) {
        detail = article
    }

    /// Only returned when queried with `maxAge: nil`, matches the real `NewsLocalDataSource`
    /// contract (a fresh, TTL-bound read misses; only the "any age" fallback read hits), so a
    /// test can actually distinguish "the primary cache check missed and the fallback saved it"
    /// from "the primary cache check already returned an answer."
    func setStaleDetail(_ article: NewsArticle) {
        staleDetail = article
    }

    func fetchArticles(query _: NewsListQuery, maxAge: TimeInterval?) async throws -> [NewsArticle] {
        maxAge == nil ? staleArticles : articles
    }

    func fetchArticleDetail(id _: String, maxAge: TimeInterval?) async throws -> NewsArticle? {
        detailMaxAges.append(maxAge)
        return maxAge == nil ? staleDetail : detail
    }

    func fetchRelatedArticles(launchID _: String, limit _: Int, maxAge _: TimeInterval?) async throws -> [NewsArticle] {
        []
    }

    func save(_ articles: [NewsArticle], fetchedAt _: Date) async throws {
        self.articles = articles
    }

    func save(_ article: NewsArticle, fetchedAt _: Date) async throws {
        detail = article
    }
}

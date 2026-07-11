//
//  NewsRepositoryTests.swift
//  TMinusTests
//
//  Created by Sadegh on 09/07/2026.
//

@testable import TMinus
import Testing
import Foundation

@Suite("NewsRepository")
enum NewsRepositoryTests {
    @Test("Articles list maps response and pagination from the remote data source")
    static func fetchArticles() async throws {
        let dataSource = MockNewsRemoteDataSource()
        dataSource.articlesResponse = NewsResponseDTO(
            count: 1,
            next: "https://api.spaceflightnewsapi.net/v4/articles/?limit=20&offset=40",
            previous: "https://api.spaceflightnewsapi.net/v4/articles/?limit=20&offset=0",
            results: [Self.makeArticleDTO(id: 1)])
        let repository = NewsRepository(remoteDataSource: dataSource)
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
            results: [Self.makeArticleDTO(id: 1), Self.makeArticleDTO(id: 2, url: "")])
        let repository = NewsRepository(remoteDataSource: dataSource)

        let page = try await repository.fetchArticles(query: NewsListQuery())

        #expect(page.items.map(\.id) == ["1"])
    }

    @Test("Article detail maps a single article")
    static func fetchArticleDetail() async throws {
        let dataSource = MockNewsRemoteDataSource()
        dataSource.detailResponse = Self.makeArticleDTO(id: 7)
        let repository = NewsRepository(remoteDataSource: dataSource)

        let article = try await repository.fetchArticleDetail(id: "7")

        #expect(article.id == "7")
        #expect(dataSource.lastDetailRequest?.id == "7")
        #expect(dataSource.lastDetailRequest?.fetchPolicy == .useCache)
    }

    @Test("Article detail throws decodingFailed when the article has no usable URL")
    static func articleDetailThrowsForUnmappableArticle() async throws {
        let dataSource = MockNewsRemoteDataSource()
        dataSource.detailResponse = Self.makeArticleDTO(id: 8, url: "")
        let repository = NewsRepository(remoteDataSource: dataSource)

        await #expect(throws: NewsError.self) {
            try await repository.fetchArticleDetail(id: "8")
        }
    }

    @Test("Related articles are fetched by launch id and compact-mapped")
    static func fetchRelatedArticles() async throws {
        let dataSource = MockNewsRemoteDataSource()
        dataSource.relatedResponse = NewsResponseDTO(
            count: 1,
            next: nil,
            previous: nil,
            results: [Self.makeArticleDTO(id: 9)])
        let repository = NewsRepository(remoteDataSource: dataSource)

        let articles = try await repository.fetchRelatedArticles(launchID: "launch-1", limit: 5)

        #expect(articles.map(\.id) == ["9"])
        #expect(dataSource.lastRelatedRequest?.launchID == "launch-1")
        #expect(dataSource.lastRelatedRequest?.limit == 5)
    }

    @Test("Transport failures are mapped to networkUnavailable")
    static func mapsTransportErrors() async throws {
        let dataSource = MockNewsRemoteDataSource()
        dataSource.articlesError = NetworkError.transport(URLError(.notConnectedToInternet))
        let repository = NewsRepository(remoteDataSource: dataSource)

        await #expect(throws: NewsError.self) {
            try await repository.fetchArticles(query: NewsListQuery())
        }
    }
}

extension NewsRepositoryTests {
    fileprivate static func makeArticleDTO(id: Int, url: String? = nil) -> NewsArticleDTO {
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
}

private final class MockNewsRemoteDataSource: NewsRemoteDataSource {
    var articlesResponse = NewsResponseDTO(count: nil, next: nil, previous: nil, results: [])
    var detailResponse = NewsRepositoryTests.makeArticleDTO(id: 0)
    var relatedResponse = NewsResponseDTO(count: nil, next: nil, previous: nil, results: [])
    var lastArticlesQuery: NewsListQuery?
    var lastDetailRequest: (id: String, fetchPolicy: FetchPolicy)?
    var lastRelatedRequest: (launchID: String, limit: Int, fetchPolicy: FetchPolicy)?
    var articlesError: Error?
    var detailError: Error?
    var relatedError: Error?

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

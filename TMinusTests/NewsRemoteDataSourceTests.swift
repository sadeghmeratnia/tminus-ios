//
//  NewsRemoteDataSourceTests.swift
//  TMinusTests
//
//  Created by Sadegh on 09/07/2026.
//

import Foundation
import Testing
@testable import TMinus

@Suite("NetworkNewsRemoteDataSource")
enum NewsRemoteDataSourceTests {
    @Test("Forwards fetch policy to network client")
    static func forwardsFetchPolicy() async throws {
        let network = MockRemoteNetworkClient()
        network.dataResponse = Self.makeArticlesPayload(articleID: 1)
        let dataSource = NetworkNewsRemoteDataSource(networkClient: network)

        let query = NewsListQuery(fetchPolicy: .networkOnly)
        let response = try await dataSource.fetchArticles(query: query)

        #expect(response.results.map(\.id) == [1])
        #expect(network.requestCount == 1)
        #expect(network.lastFetchPolicy == .networkOnly)
    }

    @Test("Related articles request uses use-cache policy passed by the caller")
    static func relatedArticlesForwardsFetchPolicy() async throws {
        let network = MockRemoteNetworkClient()
        network.dataResponse = Self.makeArticlesPayload(articleID: 2)
        let dataSource = NetworkNewsRemoteDataSource(networkClient: network)

        let response = try await dataSource.fetchRelatedArticles(launchID: "launch-1", limit: 5, fetchPolicy: .useCache)

        #expect(response.results.map(\.id) == [2])
        #expect(network.lastFetchPolicy == .useCache)
    }
}

private extension NewsRemoteDataSourceTests {
    static func makeArticlesPayload(articleID: Int) -> Data {
        Data("""
        {
          "count": 1,
          "next": null,
          "previous": null,
          "results": [
            {
              "id": \(articleID),
              "title": "Mission \(articleID)",
              "summary": "Summary",
              "url": "https://example.com/\(articleID)",
              "image_url": null,
              "news_site": "SpaceNews",
              "published_at": "2026-05-12T10:00:00Z",
              "launches": []
            }
          ]
        }
        """.utf8)
    }
}

// MARK: - MockRemoteNetworkClient

private final class MockRemoteNetworkClient: NetworkClientProtocol {
    var dataResponse = Data()
    var error: Error?
    var requestCount = 0
    var lastFetchPolicy: FetchPolicy?

    func requestData(endpoint _: Endpoint, cachePolicy: FetchPolicy) async throws -> Data {
        requestCount += 1
        lastFetchPolicy = cachePolicy
        if let error { throw error }
        return dataResponse
    }

    func request<T: Decodable & Sendable>(_ type: T.Type, endpoint: Endpoint, cachePolicy: FetchPolicy) async throws -> T {
        let data = try await requestData(endpoint: endpoint, cachePolicy: cachePolicy)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }
}

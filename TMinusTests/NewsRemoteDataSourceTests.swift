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

    @Test("Decodes a published_at timestamp with fractional seconds")
    static func decodesFractionalSecondTimestamp() async throws {
        let network = MockRemoteNetworkClient()
        network.dataResponse = Data("""
        {
          "count": 1,
          "next": null,
          "previous": null,
          "results": [
            {
              "id": 3,
              "title": "Mission 3",
              "summary": "Summary",
              "url": "https://example.com/3",
              "image_url": null,
              "news_site": "SpaceNews",
              "published_at": "2026-05-12T10:00:00.123456Z",
              "launches": []
            }
          ]
        }
        """.utf8)
        let dataSource = NetworkNewsRemoteDataSource(networkClient: network)

        let response = try await dataSource.fetchArticles(query: NewsListQuery(fetchPolicy: .networkOnly))

        #expect(response.results.map(\.id) == [3])
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

// `nonisolated(unsafe)` on every stored property: this mock is configured synchronously before
// the test's single sequential `await` call exercises it, never touched from two tasks at once,
// the same rationale as the local `nonisolated(unsafe) var` counters elsewhere in this test
// target, just at the property level since `NetworkClientProtocol: Sendable` requires this class
// to conform too.
private final class MockRemoteNetworkClient: NetworkClientProtocol {
    nonisolated(unsafe) var dataResponse = Data()
    nonisolated(unsafe) var error: Error?
    nonisolated(unsafe) var requestCount = 0
    nonisolated(unsafe) var lastFetchPolicy: FetchPolicy?

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
        // Mirrors the strategy actually configured in `TMinusApp`/`AppContainer`, using plain
        // `.iso8601` here would let this mock silently accept a fractional-second timestamp
        // format its production counterpart can't.
        decoder.dateDecodingStrategy = .flexibleISO8601
        return try decoder.decode(type, from: data)
    }
}

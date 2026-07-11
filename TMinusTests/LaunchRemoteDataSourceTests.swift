//
//  LaunchRemoteDataSourceTests.swift
//  TMinusTests
//
//  Created by Sadegh on 19/05/2026.
//

@testable import TMinus
import Testing
import Foundation

// MARK: - LaunchRemoteDataSourceTests

@Suite("NetworkLaunchRemoteDataSource")
enum LaunchRemoteDataSourceTests {
    @Test("Forwards fetch policy to network client")
    static func forwardsFetchPolicy() async throws {
        let network = MockRemoteNetworkClient()
        network.dataResponse = Self.makeLaunchesPayload(launchID: "network")
        let dataSource = NetworkLaunchRemoteDataSource(networkClient: network)

        let query = LaunchListQuery(fetchPolicy: .networkOnly)
        let response = try await dataSource.fetchUpcomingLaunches(query: query)

        #expect(response.results.map(\.id) == ["network"])
        #expect(network.requestCount == 1)
        #expect(network.lastFetchPolicy == .networkOnly)
    }
}

extension LaunchRemoteDataSourceTests {
    fileprivate static func makeLaunchesPayload(launchID: String) -> Data {
        Data("""
        {
          "results": [
            {
              "id": "\(launchID)",
              "name": "Mission \(launchID)",
              "status": { "name": "Go for Launch", "abbrev": "Go" },
              "window_start": "2026-05-12T10:00:00Z",
              "window_end": null,
              "image": null,
              "vidURLs": [],
              "rocket": null,
              "pad": null,
              "mission": null
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

    func requestData(endpoint: Endpoint, cachePolicy: FetchPolicy) async throws -> Data {
        requestCount += 1
        lastFetchPolicy = cachePolicy
        if let error { throw error }
        return dataResponse
    }

    func request<T>(_ type: T.Type, endpoint: Endpoint, cachePolicy: FetchPolicy) async throws -> T where T: Decodable & Sendable {
        let data = try await requestData(endpoint: endpoint, cachePolicy: cachePolicy)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }
}

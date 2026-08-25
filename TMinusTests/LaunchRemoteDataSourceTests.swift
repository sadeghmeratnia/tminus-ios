//
//  LaunchRemoteDataSourceTests.swift
//  TMinusTests
//
//  Created by Sadegh on 19/05/2026.
//

import Foundation
import Testing
@testable import TMinus

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

    @Test("A malformed launch in the page does not fail the whole decode")
    static func malformedLaunchDoesNotFailWholePage() async throws {
        let network = MockRemoteNetworkClient()
        network.dataResponse = Data("""
        {
          "results": [
            {
              "id": "valid-1",
              "name": "Mission 1",
              "status": { "name": "Go for Launch", "abbrev": "Go" },
              "window_start": "2026-05-12T10:00:00Z",
              "window_end": null,
              "image": null,
              "vid_urls": [],
              "rocket": null,
              "pad": null,
              "mission": null
            },
            {
              "id": "missing-window-start",
              "name": "Mission 2",
              "status": null,
              "window_end": null,
              "image": null,
              "vid_urls": [],
              "rocket": null,
              "pad": null,
              "mission": null
            },
            {
              "id": "valid-2",
              "name": "Mission 3",
              "status": null,
              "window_start": "2026-05-13T10:00:00Z",
              "window_end": null,
              "image": null,
              "vid_urls": [],
              "rocket": null,
              "pad": null,
              "mission": null
            }
          ]
        }
        """.utf8)
        let dataSource = NetworkLaunchRemoteDataSource(networkClient: network)

        let response = try await dataSource.fetchUpcomingLaunches(query: LaunchListQuery())

        #expect(response.results.map(\.id) == ["valid-1", "valid-2"])
    }
}

private extension LaunchRemoteDataSourceTests {
    static func makeLaunchesPayload(launchID: String) -> Data {
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
              "vid_urls": [],
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
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }
}

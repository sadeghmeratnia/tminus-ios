//
//  LaunchRepositoryTests.swift
//  TMinusTests
//
//  Created by Codex on 12/05/2026.
//

@testable import TMinus
import Testing
import Foundation

@Suite("LaunchRepository")
enum LaunchRepositoryTests {
    @Test("Upcoming launches forwards cache policy and maps response")
    static func fetchUpcomingLaunches() async throws {
        let responseDTO = try decodeLaunchesResponseDTO(json: """
        {
          "results": [
            {
              "id": "launch-1",
              "name": "Starlink Mission",
              "status": { "name": "Go for Launch", "abbrev": "Go" },
              "window_start": "2026-05-12T10:00:00Z",
              "window_end": null,
              "image": { "thumbnail_url": "https://img.example.com/mission.png" },
              "vidURLs": [{ "url": "https://youtube.com/watch?v=1", "priority": 1 }],
              "rocket": { "configuration": { "id": 9, "name": "Falcon 9" } },
              "pad": {
                "id": 10,
                "name": "LC-39A",
                "latitude": 28.6084,
                "longitude": -80.6043,
                "location": { "name": "Kennedy Space Center" }
              },
              "mission": {
                "id": 99,
                "name": "Starlink Batch",
                "description": "Deploy satellites",
                "type": "Communications",
                "orbit": { "name": "LEO" }
              }
            }
          ]
        }
        """)

        let client = MockLaunchNetworkClient()
        client.typedResponse = responseDTO
        let repository = LaunchRepository(networkClient: client)
        let query = LaunchListQuery(page: 2, limit: 20, searchText: "star", cachePolicy: .networkOnly)

        let launches = try await repository.fetchUpcomingLaunches(query: query)

        #expect(launches.count == 1)
        #expect(launches.first?.id == "launch-1")
        #expect(launches.first?.status == .go)
        #expect(client.lastCachePolicy == .networkOnly)
        #expect(client.lastEndpoint?.path == "launches/upcoming/")
        #expect(client.lastEndpoint?.queryItems.contains(URLQueryItem(name: "search", value: "star")) == true)
        #expect(client.lastEndpoint?.queryItems.contains(URLQueryItem(name: "offset", value: "20")) == true)
    }

    @Test("Previous launches forwards use-cache policy")
    static func fetchPreviousLaunches() async throws {
        let responseDTO = try decodeLaunchesResponseDTO(json: """
        { "results": [] }
        """)

        let client = MockLaunchNetworkClient()
        client.typedResponse = responseDTO
        let repository = LaunchRepository(networkClient: client)
        let query = LaunchListQuery(page: 1, limit: 20, cachePolicy: .useCache)

        _ = try await repository.fetchPreviousLaunches(query: query)

        #expect(client.lastCachePolicy == .useCache)
        #expect(client.lastEndpoint?.path == "launches/previous/")
        #expect(client.lastEndpoint?.queryItems.contains(URLQueryItem(name: "ordering", value: "-window_start")) == true)
    }
}

private extension LaunchRepositoryTests {
    static func decodeLaunchesResponseDTO(json: String) throws -> LaunchesResponseDTO {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(LaunchesResponseDTO.self, from: Data(json.utf8))
    }
}

private enum MockLaunchNetworkClientError: Error {
    case missingTypedResponse
    case typeMismatch
}

private final class MockLaunchNetworkClient: NetworkClientProtocol {
    var lastEndpoint: Endpoint?
    var lastCachePolicy: CachePolicy?
    var typedResponse: Any?

    func requestData(endpoint: Endpoint, cachePolicy: CachePolicy) async throws -> Data {
        lastEndpoint = endpoint
        lastCachePolicy = cachePolicy
        return Data()
    }

    func request<T>(_ type: T.Type, endpoint: Endpoint, cachePolicy: CachePolicy) async throws -> T where T: Decodable {
        lastEndpoint = endpoint
        lastCachePolicy = cachePolicy
        guard let typedResponse else { throw MockLaunchNetworkClientError.missingTypedResponse }
        guard let casted = typedResponse as? T else { throw MockLaunchNetworkClientError.typeMismatch }
        return casted
    }
}

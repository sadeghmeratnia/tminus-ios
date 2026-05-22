//
//  LaunchRepositoryTests.swift
//  TMinusTests
//
//  Created by Sadegh on 12/05/2026.
//

@testable import TMinus
import Testing
import Foundation

@Suite("LaunchRepository")
enum LaunchRepositoryTests {
    @Test("Upcoming launches maps response from remote data source")
    static func fetchUpcomingLaunches() async throws {
        let dataSource = MockLaunchRemoteDataSource()
        dataSource.upcomingResponse = Self.makeLaunchesResponseDTO()
        let repository = LaunchRepository(remoteDataSource: dataSource)
        let query = LaunchListQuery(page: 2, limit: 20, searchText: "star", fetchPolicy: .networkOnly)

        let launches = try await repository.fetchUpcomingLaunches(query: query)

        #expect(launches.count == 1)
        #expect(launches.first?.id == "launch-1")
        #expect(launches.first?.status == .go)
        #expect(dataSource.lastUpcomingQuery == query)
    }

    @Test("Previous launches maps response from remote data source")
    static func fetchPreviousLaunches() async throws {
        let dataSource = MockLaunchRemoteDataSource()
        dataSource.previousResponse = LaunchesResponseDTO(results: [])
        let repository = LaunchRepository(remoteDataSource: dataSource)
        let query = LaunchListQuery(page: 1, limit: 20, fetchPolicy: .useCache)

        let launches = try await repository.fetchPreviousLaunches(query: query)

        #expect(launches.isEmpty)
        #expect(dataSource.lastPreviousQuery == query)
    }

    @Test("Launch detail uses use-cache fetch policy")
    static func fetchLaunchDetailUsesUseCachePolicy() async throws {
        let dataSource = MockLaunchRemoteDataSource()
        dataSource.detailResponse = Self.makeLaunchDTO(id: "detail-1")
        let repository = LaunchRepository(remoteDataSource: dataSource)

        let launch = try await repository.fetchLaunchDetail(id: "detail-1")
        #expect(launch.id == "detail-1")
        #expect(dataSource.lastDetailRequest?.id == "detail-1")
        #expect(dataSource.lastDetailRequest?.fetchPolicy == .useCache)
    }

    @Test("Uses local cache first for upcoming launches")
    static func usesLocalCacheFirstForUpcoming() async throws {
        let dataSource = MockLaunchRemoteDataSource()
        let localDataSource = MockLaunchLocalDataSource()
        await localDataSource.setUpcoming([
            Launch(
                id: "local-1",
                name: "Local Launch",
                status: .go,
                windowStart: Date(timeIntervalSince1970: 1_000),
                windowEnd: nil,
                rocket: LaunchRocket(id: 1, name: "Falcon 9"),
                launchPad: LaunchPad(id: "1", name: "LC-39A", latitude: 0, longitude: 0, locationName: nil),
                mission: nil,
                imageURL: nil,
                webcastURL: nil),
        ])
        let repository = LaunchRepository(remoteDataSource: dataSource, localDataSource: localDataSource)

        let launches = try await repository.fetchUpcomingLaunches(query: LaunchListQuery(fetchPolicy: .useCache))

        #expect(launches.map(\.id) == ["local-1"])
        #expect(dataSource.lastUpcomingQuery == nil)
        let maxAges = await localDataSource.upcomingMaxAges
        #expect(maxAges == [120.0])
    }

    @Test("Falls back to stale local cache when upcoming network fails")
    static func fallsBackToStaleUpcomingWhenNetworkFails() async throws {
        let dataSource = MockLaunchRemoteDataSource()
        dataSource.upcomingError = NetworkError.transport(URLError(.notConnectedToInternet))
        let localDataSource = MockLaunchLocalDataSource()
        await localDataSource.setStaleUpcoming([
            Launch(
                id: "stale-1",
                name: "Stale Launch",
                status: .go,
                windowStart: Date(timeIntervalSince1970: 1_000),
                windowEnd: nil,
                rocket: LaunchRocket(id: 1, name: "Falcon 9"),
                launchPad: LaunchPad(id: "1", name: "LC-39A", latitude: 0, longitude: 0, locationName: nil),
                mission: nil,
                imageURL: nil,
                webcastURL: nil),
        ])
        let repository = LaunchRepository(remoteDataSource: dataSource, localDataSource: localDataSource)

        let launches = try await repository.fetchUpcomingLaunches(query: LaunchListQuery(fetchPolicy: .useCache))

        #expect(launches.map(\.id) == ["stale-1"])
        let maxAges = await localDataSource.upcomingMaxAges
        #expect(maxAges == [120.0, nil])
    }
}

private extension LaunchRepositoryTests {
    static func makeLaunchesResponseDTO() -> LaunchesResponseDTO {
        LaunchesResponseDTO(results: [makeLaunchDTO(id: "launch-1")])
    }

    static func makeLaunchDTO(id: String) -> LaunchDTO {
        let json = """
        {
          "id": "\(id)",
          "name": "Starlink Mission",
          "status": { "name": "Go for Launch", "abbrev": "Go" },
          "window_start": "2026-05-12T10:00:00Z",
          "window_end": null,
          "image": null,
          "vidURLs": [],
          "rocket": null,
          "pad": null,
          "mission": null
        }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try! decoder.decode(LaunchDTO.self, from: Data(json.utf8))
    }
}

private final class MockLaunchRemoteDataSource: LaunchRemoteDataSource {
    var upcomingResponse = LaunchesResponseDTO(results: [])
    var previousResponse = LaunchesResponseDTO(results: [])
    var detailResponse = LaunchRepositoryTests.makeLaunchDTO(id: "detail")
    var lastUpcomingQuery: LaunchListQuery?
    var lastPreviousQuery: LaunchListQuery?
    var lastDetailRequest: (id: String, fetchPolicy: LaunchFetchPolicy)?
    var upcomingError: Error?
    var previousError: Error?
    var detailError: Error?

    func fetchUpcomingLaunches(query: LaunchListQuery) async throws -> LaunchesResponseDTO {
        if let upcomingError { throw upcomingError }
        lastUpcomingQuery = query
        return upcomingResponse
    }

    func fetchPreviousLaunches(query: LaunchListQuery) async throws -> LaunchesResponseDTO {
        if let previousError { throw previousError }
        lastPreviousQuery = query
        return previousResponse
    }

    func fetchLaunchDetail(id: String, fetchPolicy: LaunchFetchPolicy) async throws -> LaunchDTO {
        if let detailError { throw detailError }
        lastDetailRequest = (id, fetchPolicy)
        return detailResponse
    }
}

private actor MockLaunchLocalDataSource: LaunchLocalDataSource {
    private var upcoming: [Launch] = []
    private var staleUpcoming: [Launch] = []
    private var previous: [Launch] = []
    private var detail: Launch?
    private(set) var upcomingMaxAges: [TimeInterval?] = []
    private(set) var previousMaxAges: [TimeInterval?] = []
    private(set) var detailMaxAges: [TimeInterval?] = []

    func setUpcoming(_ launches: [Launch]) {
        upcoming = launches
    }

    func setStaleUpcoming(_ launches: [Launch]) {
        staleUpcoming = launches
    }

    func fetchUpcomingLaunches(query: LaunchListQuery, maxAge: TimeInterval?) async throws -> [Launch] {
        upcomingMaxAges.append(maxAge)
        if maxAge == nil {
            return staleUpcoming
        }
        return upcoming
    }

    func fetchPreviousLaunches(query: LaunchListQuery, maxAge: TimeInterval?) async throws -> [Launch] {
        previousMaxAges.append(maxAge)
        return previous
    }

    func fetchLaunchDetail(id: String, maxAge: TimeInterval?) async throws -> Launch? {
        detailMaxAges.append(maxAge)
        return detail
    }

    func save(_ launches: [Launch], fetchedAt: Date) async throws {
        if launches.first?.windowStart ?? .distantFuture >= Date() {
            upcoming = launches
        } else {
            previous = launches
        }
    }

    func save(_ launch: Launch, fetchedAt: Date) async throws {
        detail = launch
    }
}

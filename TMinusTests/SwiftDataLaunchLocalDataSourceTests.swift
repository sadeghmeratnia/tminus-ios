//
//  SwiftDataLaunchLocalDataSourceTests.swift
//  TMinusTests
//
//  Created by Sadegh on 13/07/2026.
//

import Foundation
import SwiftData
import Testing
@testable import TMinus

@Suite("SwiftDataLaunchLocalDataSource")
struct SwiftDataLaunchLocalDataSourceTests {
    @Test("save inserts new launches")
    func saveInsertsNewLaunches() async throws {
        let dataSource = try Self.makeDataSource()
        let launches = [Self.makeLaunch(id: "1"), Self.makeLaunch(id: "2")]

        try await dataSource.save(launches, fetchedAt: .now)

        let fetched = try await dataSource.fetchUpcomingLaunches(query: LaunchListQuery(), maxAge: nil)
        #expect(Set(fetched.map(\.id)) == ["1", "2"])
    }

    @Test("save updates existing launches in place rather than duplicating them")
    func saveUpdatesExistingLaunchesInPlace() async throws {
        let dataSource = try Self.makeDataSource()
        try await dataSource.save([Self.makeLaunch(id: "1", name: "Original Name")], fetchedAt: .now)

        try await dataSource.save([Self.makeLaunch(id: "1", name: "Updated Name")], fetchedAt: .now)

        let fetched = try await dataSource.fetchUpcomingLaunches(query: LaunchListQuery(), maxAge: nil)
        #expect(fetched.count == 1)
        #expect(fetched.first?.name == "Updated Name")
    }

    @Test("save collapses a duplicate id within the same batch into a single row")
    func saveCollapsesDuplicateIDWithinSameBatch() async throws {
        let dataSource = try Self.makeDataSource()

        // A single batch containing the same id twice (e.g. a malformed API page) must not
        // create two rows sharing an id — the second occurrence should update the first.
        try await dataSource.save(
            [Self.makeLaunch(id: "1", name: "First Occurrence"), Self.makeLaunch(id: "1", name: "Second Occurrence")],
            fetchedAt: .now
        )

        let fetched = try await dataSource.fetchUpcomingLaunches(query: LaunchListQuery(), maxAge: nil)
        #expect(fetched.count == 1)
        #expect(fetched.first?.name == "Second Occurrence")
    }

    @Test("save handles a mix of new and existing launches in one batch")
    func saveHandlesMixedInsertAndUpdate() async throws {
        let dataSource = try Self.makeDataSource()
        try await dataSource.save([Self.makeLaunch(id: "1", name: "Original Name")], fetchedAt: .now)

        try await dataSource.save(
            [Self.makeLaunch(id: "1", name: "Updated Name"), Self.makeLaunch(id: "2", name: "Brand New")],
            fetchedAt: .now
        )

        let fetched = try await dataSource.fetchUpcomingLaunches(query: LaunchListQuery(limit: 20), maxAge: nil)
        #expect(fetched.count == 2)
        #expect(fetched.first(where: { $0.id == "1" })?.name == "Updated Name")
        #expect(fetched.first(where: { $0.id == "2" })?.name == "Brand New")
    }

    // MARK: - Pagination

    @Test("page 1 returns the earliest launches within the limit, in ascending window order")
    func fetchUpcomingFirstPageReturnsEarliestWithinLimit() async throws {
        let dataSource = try Self.makeDataSource()
        try await dataSource.save(Self.makeAscendingLaunches(count: 5), fetchedAt: .now)

        let page = try await dataSource.fetchUpcomingLaunches(
            query: LaunchListQuery(page: 1, limit: 2),
            maxAge: nil
        )

        #expect(page.map(\.id) == ["1", "2"])
    }

    @Test("page 2 returns the next slice, not overlapping page 1")
    func fetchUpcomingSecondPageReturnsNextSlice() async throws {
        let dataSource = try Self.makeDataSource()
        try await dataSource.save(Self.makeAscendingLaunches(count: 5), fetchedAt: .now)

        let page = try await dataSource.fetchUpcomingLaunches(
            query: LaunchListQuery(page: 2, limit: 2),
            maxAge: nil
        )

        #expect(page.map(\.id) == ["3", "4"])
    }

    @Test("a page past the end returns only the remaining partial results")
    func fetchUpcomingPagePastEndReturnsPartialResults() async throws {
        let dataSource = try Self.makeDataSource()
        try await dataSource.save(Self.makeAscendingLaunches(count: 5), fetchedAt: .now)

        let page = try await dataSource.fetchUpcomingLaunches(
            query: LaunchListQuery(page: 3, limit: 2),
            maxAge: nil
        )

        #expect(page.map(\.id) == ["5"])
    }

    // MARK: - TTL

    @Test("a row older than maxAge is excluded from results")
    func fetchUpcomingExcludesRowsOlderThanMaxAge() async throws {
        let dataSource = try Self.makeDataSource()
        try await dataSource.save(
            [Self.makeLaunch(id: "stale")],
            fetchedAt: Date(timeIntervalSinceNow: -1000)
        )

        let fetched = try await dataSource.fetchUpcomingLaunches(query: LaunchListQuery(), maxAge: 10)

        #expect(fetched.isEmpty)
    }

    @Test("a row within maxAge is included in results")
    func fetchUpcomingIncludesRowsWithinMaxAge() async throws {
        let dataSource = try Self.makeDataSource()
        try await dataSource.save(
            [Self.makeLaunch(id: "fresh")],
            fetchedAt: Date(timeIntervalSinceNow: -1000)
        )

        let fetched = try await dataSource.fetchUpcomingLaunches(query: LaunchListQuery(), maxAge: 2000)

        #expect(fetched.map(\.id) == ["fresh"])
    }

    @Test("a nil maxAge never filters by staleness")
    func fetchUpcomingNilMaxAgeIncludesArbitrarilyOldRows() async throws {
        let dataSource = try Self.makeDataSource()
        try await dataSource.save(
            [Self.makeLaunch(id: "ancient")],
            fetchedAt: Date(timeIntervalSinceNow: -60 * 60 * 24 * 365)
        )

        let fetched = try await dataSource.fetchUpcomingLaunches(query: LaunchListQuery(), maxAge: nil)

        #expect(fetched.map(\.id) == ["ancient"])
    }

    // MARK: - Search

    @Test("search text filters to launches whose name contains it, case-insensitively")
    func fetchUpcomingFiltersBySearchText() async throws {
        let dataSource = try Self.makeDataSource()
        try await dataSource.save(
            [Self.makeLaunch(id: "1", name: "Starship Flight 5"), Self.makeLaunch(id: "2", name: "Falcon Heavy")],
            fetchedAt: .now
        )

        let fetched = try await dataSource.fetchUpcomingLaunches(
            query: LaunchListQuery(searchText: "STARSHIP"),
            maxAge: nil
        )

        #expect(fetched.map(\.id) == ["1"])
    }

    @Test("search text with no matches returns an empty result, not every row")
    func fetchUpcomingSearchTextWithNoMatchesReturnsEmpty() async throws {
        let dataSource = try Self.makeDataSource()
        try await dataSource.save([Self.makeLaunch(id: "1", name: "Starship Flight 5")], fetchedAt: .now)

        let fetched = try await dataSource.fetchUpcomingLaunches(
            query: LaunchListQuery(searchText: "artemis"),
            maxAge: nil
        )

        #expect(fetched.isEmpty)
    }

    // MARK: - Upcoming / previous window split

    @Test("upcoming and previous are partitioned by windowStart relative to now")
    func fetchesPartitionByWindowStartRelativeToNow() async throws {
        let dataSource = try Self.makeDataSource()
        let future = Self.makeLaunch(id: "future", windowStart: Date(timeIntervalSinceNow: 60 * 60 * 24))
        let past = Self.makeLaunch(id: "past", windowStart: Date(timeIntervalSinceNow: -60 * 60 * 24))
        try await dataSource.save([future, past], fetchedAt: .now)

        let upcoming = try await dataSource.fetchUpcomingLaunches(query: LaunchListQuery(), maxAge: nil)
        let previous = try await dataSource.fetchPreviousLaunches(query: LaunchListQuery(), maxAge: nil)

        #expect(upcoming.map(\.id) == ["future"])
        #expect(previous.map(\.id) == ["past"])
    }

    @Test("previous launches are sorted most-recent-first")
    func fetchPreviousLaunchesSortedMostRecentFirst() async throws {
        let dataSource = try Self.makeDataSource()
        let launches = [
            Self.makeLaunch(id: "oldest", windowStart: Date(timeIntervalSinceNow: -60 * 60 * 24 * 3)),
            Self.makeLaunch(id: "newest", windowStart: Date(timeIntervalSinceNow: -60 * 60 * 24)),
            Self.makeLaunch(id: "middle", windowStart: Date(timeIntervalSinceNow: -60 * 60 * 24 * 2))
        ]
        try await dataSource.save(launches, fetchedAt: .now)

        let previous = try await dataSource.fetchPreviousLaunches(query: LaunchListQuery(limit: 20), maxAge: nil)

        #expect(previous.map(\.id) == ["newest", "middle", "oldest"])
    }
}

private extension SwiftDataLaunchLocalDataSourceTests {
    static func makeDataSource() throws -> SwiftDataLaunchLocalDataSource {
        let schema = Schema([LaunchLocalModel.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return SwiftDataLaunchLocalDataSource(container: container)
    }

    static func makeLaunch(id: String,
                           name: String = "Mission",
                           // Far in the future so it always lands in "upcoming" by default,
                           // regardless of when the test runs.
                           windowStart: Date = Date(timeIntervalSinceNow: 60 * 60 * 24 * 365)) -> Launch {
        Launch(
            id: id,
            name: name,
            status: .go,
            windowStart: windowStart,
            windowEnd: nil,
            rocket: nil,
            launchPad: nil,
            mission: nil,
            imageURL: nil,
            webcastURL: nil
        )
    }

    /// Five upcoming launches with ids "1"..."5", `windowStart` strictly ascending — id "1" is
    /// soonest, id "5" is furthest out — so pagination order is deterministic and easy to assert.
    static func makeAscendingLaunches(count: Int) -> [Launch] {
        (1 ... count).map {
            makeLaunch(id: "\($0)", windowStart: Date(timeIntervalSinceNow: 60 * 60 * 24 * Double($0)))
        }
    }
}

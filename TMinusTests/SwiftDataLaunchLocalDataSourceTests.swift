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
        // create two rows sharing an id, the second occurrence should update the first.
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

    @Test("page 2 returns nothing — cache only ever serves page 1 by design")
    func fetchUpcomingSecondPageReturnsEmpty() async throws {
        // Offset/limit paging against a store that can be mutated concurrently (a background
        // `save` inserting a row that sorts ahead of the offset already consumed) isn't stable
        // beyond the first page, so the data source refuses to serve page > 1 from cache at all
        // rather than risk silently skipping a launch. Every real caller already only ever
        // fetches page 1 from cache (`loadMore`/`retryLoadMore` use `.networkOnly`), this is
        // the data source enforcing that as a guarantee.
        let dataSource = try Self.makeDataSource()
        try await dataSource.save(Self.makeAscendingLaunches(count: 5), fetchedAt: .now)

        let page = try await dataSource.fetchUpcomingLaunches(
            query: LaunchListQuery(page: 2, limit: 2),
            maxAge: nil
        )

        #expect(page.isEmpty)
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

    @Test("a resolved launch (success/failure) is previous regardless of window")
    func fetchesPartitionByWindowStartRelativeToNow() async throws {
        let future = Self.makeLaunch(id: "future", windowStart: Date(timeIntervalSinceNow: 60 * 60 * 24))
        // Resolved (flown) rather than merely past-window, so it's unambiguously "previous",
        // see "a launch past its window but not yet resolved stays upcoming" for the other half
        // of this split.
        let past = Self.makeLaunch(id: "past", status: .success, windowStart: Date(timeIntervalSinceNow: -60 * 60 * 24))
        let dataSource = try Self.makeDataSource()
        try await dataSource.save([future, past], fetchedAt: .now)

        let upcoming = try await dataSource.fetchUpcomingLaunches(query: LaunchListQuery(), maxAge: nil)
        let previous = try await dataSource.fetchPreviousLaunches(query: LaunchListQuery(), maxAge: nil)

        #expect(upcoming.map(\.id) == ["future"])
        #expect(previous.map(\.id) == ["past"])
    }

    @Test("a launch past its window but not yet resolved stays upcoming")
    func fetchUpcomingKeepsUnresolvedLaunchPastItsWindow() async throws {
        // Mirrors the remote Launch Library API's own status-first semantics: a launch whose
        // window has slipped into the past but whose status hasn't been updated to success/
        // failure yet (still "go"/"tbd"/"hold") stays upcoming, so it doesn't flip tabs locally
        // ahead of the remote API agreeing it's resolved.
        let dataSource = try Self.makeDataSource()
        let slipped = Self.makeLaunch(id: "slipped", status: .hold, windowStart: Date(timeIntervalSinceNow: -60 * 60 * 24))
        try await dataSource.save([slipped], fetchedAt: .now)

        let upcoming = try await dataSource.fetchUpcomingLaunches(query: LaunchListQuery(), maxAge: nil)
        let previous = try await dataSource.fetchPreviousLaunches(query: LaunchListQuery(), maxAge: nil)

        #expect(upcoming.map(\.id) == ["slipped"])
        #expect(previous.isEmpty)
    }

    @Test("a launch with an unrecognized status falls back to the window comparison")
    func fetchLaunchesWithUnknownStatusFallsBackToWindow() async throws {
        // Covers a real Launch Library status `LaunchDTOMapper.mapStatus` doesn't recognize
        // (e.g. "Partial Failure", "In Flight"), mapped to `.unknown`, which isn't in
        // `resolvedStatusCodes`. A pure status split would leave a launch like this, almost
        // always already resolved, since an unparsed status essentially only occurs for launches
        // that have already flown, permanently stuck in "upcoming". The window comparison
        // should still correctly sort it into "previous" once its window has passed, and
        // "upcoming" while it hasn't.
        let dataSource = try Self.makeDataSource()
        let pastUnknown = Self.makeLaunch(
            id: "past-unknown",
            status: .unknown("Partial Failure"),
            windowStart: Date(timeIntervalSinceNow: -60 * 60 * 24)
        )
        let futureUnknown = Self.makeLaunch(
            id: "future-unknown",
            status: .unknown("TBC"),
            windowStart: Date(timeIntervalSinceNow: 60 * 60 * 24)
        )
        try await dataSource.save([pastUnknown, futureUnknown], fetchedAt: .now)

        let upcoming = try await dataSource.fetchUpcomingLaunches(query: LaunchListQuery(), maxAge: nil)
        let previous = try await dataSource.fetchPreviousLaunches(query: LaunchListQuery(), maxAge: nil)

        #expect(upcoming.map(\.id) == ["future-unknown"])
        #expect(previous.map(\.id) == ["past-unknown"])
    }

    @Test("previous launches are sorted most-recent-first")
    func fetchPreviousLaunchesSortedMostRecentFirst() async throws {
        let dataSource = try Self.makeDataSource()
        // Resolved status, see "a resolved launch is previous regardless of window", since
        // "previous" is now a pure status partition rather than a window comparison.
        let launches = [
            Self.makeLaunch(id: "oldest", status: .success, windowStart: Date(timeIntervalSinceNow: -60 * 60 * 24 * 3)),
            Self.makeLaunch(id: "newest", status: .success, windowStart: Date(timeIntervalSinceNow: -60 * 60 * 24)),
            Self.makeLaunch(id: "middle", status: .success, windowStart: Date(timeIntervalSinceNow: -60 * 60 * 24 * 2))
        ]
        try await dataSource.save(launches, fetchedAt: .now)

        let previous = try await dataSource.fetchPreviousLaunches(query: LaunchListQuery(limit: 20), maxAge: nil)

        #expect(previous.map(\.id) == ["newest", "middle", "oldest"])
    }

    @Test("a row far older than any maxAge is eventually pruned from disk, not just hidden from queries")
    func savePeriodicallyPrunesVeryStaleRows() async throws {
        let dataSource = try Self.makeDataSource()
        let ancientFetchDate = Date().addingTimeInterval(-60 * 60 * 24 * 31) // 31 days ago
        try await dataSource.save(Self.makeLaunch(id: "ancient"), fetchedAt: ancientFetchDate)

        // A `nil` maxAge alone would still return "ancient" if it were merely hidden by a query
        // filter, so it's confirmed present first, proving the later absence is an actual
        // deletion, not just this same "nil bypasses staleness" behavior some other test already
        // covers.
        let beforePrune = try await dataSource.fetchLaunchDetail(id: "ancient", maxAge: nil)
        #expect(beforePrune != nil)

        // Pruning runs every 25 `save` calls (see `SwiftDataLaunchLocalDataSource.Constants`);
        // the "ancient" save above was the 1st, so 24 more trigger it on the 25th.
        for index in 0 ..< 24 {
            try await dataSource.save(Self.makeLaunch(id: "filler-\(index)"), fetchedAt: .now)
        }

        let afterPrune = try await dataSource.fetchLaunchDetail(id: "ancient", maxAge: nil)
        #expect(afterPrune == nil)
    }
}

private extension SwiftDataLaunchLocalDataSourceTests {
    static func makeDataSource() throws -> SwiftDataLaunchLocalDataSource {
        let schema = Schema([LaunchLocalModel.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        // A fresh, uniquely-named suite per data source instance, not `.standard`, so the
        // persisted `lastPruneDate` (see `SwiftDataLaunchLocalDataSource`) can't leak between
        // test runs or bleed into the real app's defaults.
        let userDefaults = UserDefaults(suiteName: UUID().uuidString)!
        return SwiftDataLaunchLocalDataSource(container: container, userDefaults: userDefaults)
    }

    static func makeLaunch(id: String,
                           name: String = "Mission",
                           // Unresolved by default so it lands in "upcoming" unless a test
                           // explicitly asks for a resolved (previous) launch.
                           status: LaunchStatus = .go,
                           // Far in the future so it always lands in "upcoming" by default,
                           // regardless of when the test runs.
                           windowStart: Date = Date(timeIntervalSinceNow: 60 * 60 * 24 * 365)) -> Launch {
        Launch(
            id: id,
            name: name,
            status: status,
            windowStart: windowStart,
            windowEnd: nil,
            rocket: nil,
            launchPad: nil,
            mission: nil,
            imageURL: nil,
            webcastURL: nil
        )
    }

    /// Five upcoming launches with ids "1"..."5", `windowStart` strictly ascending, id "1" is
    /// soonest, id "5" is furthest out, so pagination order is deterministic and easy to assert.
    static func makeAscendingLaunches(count: Int) -> [Launch] {
        (1 ... count).map {
            makeLaunch(id: "\($0)", windowStart: Date(timeIntervalSinceNow: 60 * 60 * 24 * Double($0)))
        }
    }
}

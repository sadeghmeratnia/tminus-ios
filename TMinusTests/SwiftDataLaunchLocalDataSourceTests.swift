//
//  SwiftDataLaunchLocalDataSourceTests.swift
//  TMinusTests
//
//  Created by Sadegh on 13/07/2026.
//

@testable import TMinus
import Testing
import Foundation
import SwiftData

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
            fetchedAt: .now)

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
            fetchedAt: .now)

        let fetched = try await dataSource.fetchUpcomingLaunches(query: LaunchListQuery(limit: 20), maxAge: nil)
        #expect(fetched.count == 2)
        #expect(fetched.first(where: { $0.id == "1" })?.name == "Updated Name")
        #expect(fetched.first(where: { $0.id == "2" })?.name == "Brand New")
    }
}

extension SwiftDataLaunchLocalDataSourceTests {
    fileprivate static func makeDataSource() throws -> SwiftDataLaunchLocalDataSource {
        let schema = Schema([LaunchLocalModel.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return SwiftDataLaunchLocalDataSource(container: container)
    }

    fileprivate static func makeLaunch(id: String, name: String = "Mission") -> Launch {
        Launch(
            id: id,
            name: name,
            status: .go,
            // Far in the future so it always lands in "upcoming" regardless of when the test runs.
            windowStart: Date(timeIntervalSinceNow: 60 * 60 * 24 * 365),
            windowEnd: nil,
            rocket: nil,
            launchPad: nil,
            mission: nil,
            imageURL: nil,
            webcastURL: nil)
    }
}

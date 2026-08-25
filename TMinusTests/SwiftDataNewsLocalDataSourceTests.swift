//
//  SwiftDataNewsLocalDataSourceTests.swift
//  TMinusTests
//
//  Created by Sadegh on 13/08/2026.
//

import Foundation
import SwiftData
import Testing
@testable import TMinus

@Suite("SwiftDataNewsLocalDataSource")
struct SwiftDataNewsLocalDataSourceTests {
    @Test("save inserts new articles")
    func saveInsertsNewArticles() async throws {
        let dataSource = try Self.makeDataSource()
        let articles = [Self.makeArticle(id: "1"), Self.makeArticle(id: "2")]

        try await dataSource.save(articles, fetchedAt: .now)

        let fetched = try await dataSource.fetchArticles(query: NewsListQuery(), maxAge: nil)
        #expect(Set(fetched.map(\.id)) == ["1", "2"])
    }

    @Test("save updates an existing article in place rather than duplicating it")
    func saveUpdatesExistingArticleInPlace() async throws {
        let dataSource = try Self.makeDataSource()
        try await dataSource.save([Self.makeArticle(id: "1", title: "Original Title")], fetchedAt: .now)

        try await dataSource.save([Self.makeArticle(id: "1", title: "Updated Title")], fetchedAt: .now)

        let fetched = try await dataSource.fetchArticles(query: NewsListQuery(), maxAge: nil)
        #expect(fetched.count == 1)
        #expect(fetched.first?.title == "Updated Title")
    }

    // See `SwiftDataLaunchLocalDataSourceTests.saveCollapsesDuplicateIDWithinSameBatch`, this
    // batch-mutation logic is copy-pasted between the two data sources, so a regression in one
    // wouldn't be caught symmetrically without a matching test here.
    @Test("save collapses a duplicate id within the same batch into a single row")
    func saveCollapsesDuplicateIDWithinSameBatch() async throws {
        let dataSource = try Self.makeDataSource()

        try await dataSource.save(
            [Self.makeArticle(id: "1", title: "First Occurrence"), Self.makeArticle(id: "1", title: "Second Occurrence")],
            fetchedAt: .now
        )

        let fetched = try await dataSource.fetchArticles(query: NewsListQuery(), maxAge: nil)
        #expect(fetched.count == 1)
        #expect(fetched.first?.title == "Second Occurrence")
    }

    @Test("save handles a mix of new and existing articles in one batch")
    func saveHandlesMixedInsertAndUpdate() async throws {
        let dataSource = try Self.makeDataSource()
        try await dataSource.save([Self.makeArticle(id: "1", title: "Original Title")], fetchedAt: .now)

        try await dataSource.save(
            [Self.makeArticle(id: "1", title: "Updated Title"), Self.makeArticle(id: "2", title: "Brand New")],
            fetchedAt: .now
        )

        let fetched = try await dataSource.fetchArticles(query: NewsListQuery(), maxAge: nil)
        #expect(Set(fetched.map(\.id)) == ["1", "2"])
        #expect(fetched.first(where: { $0.id == "1" })?.title == "Updated Title")
    }

    @Test("page 1 returns the most recently published articles within the limit")
    func fetchArticlesFirstPageReturnsNewestWithinLimit() async throws {
        let dataSource = try Self.makeDataSource()
        let articles = (1 ... 5).map {
            Self.makeArticle(id: "\($0)", publishedAt: Date(timeIntervalSince1970: Double($0) * 1000))
        }
        try await dataSource.save(articles, fetchedAt: .now)

        let fetched = try await dataSource.fetchArticles(query: NewsListQuery(limit: 3), maxAge: nil)

        #expect(fetched.map(\.id) == ["5", "4", "3"])
    }

    @Test("page 2 returns nothing — cache only ever serves page 1 by design")
    func fetchArticlesSecondPageReturnsEmpty() async throws {
        let dataSource = try Self.makeDataSource()
        try await dataSource.save([Self.makeArticle(id: "1")], fetchedAt: .now)

        let fetched = try await dataSource.fetchArticles(query: NewsListQuery(page: 2, limit: 20), maxAge: nil)

        #expect(fetched.isEmpty)
    }

    @Test("a row older than maxAge is excluded from results")
    func fetchArticlesExcludesRowsOlderThanMaxAge() async throws {
        let dataSource = try Self.makeDataSource()
        try await dataSource.save(
            Self.makeArticle(id: "1"),
            fetchedAt: Date(timeIntervalSinceNow: -1000)
        )

        let fetched = try await dataSource.fetchArticles(query: NewsListQuery(), maxAge: 100)

        #expect(fetched.isEmpty)
    }

    @Test("a nil maxAge never filters by staleness")
    func fetchArticlesNilMaxAgeIncludesArbitrarilyOldRows() async throws {
        let dataSource = try Self.makeDataSource()
        try await dataSource.save(
            Self.makeArticle(id: "1"),
            fetchedAt: Date(timeIntervalSinceNow: -60 * 60 * 24 * 365)
        )

        let fetched = try await dataSource.fetchArticles(query: NewsListQuery(), maxAge: nil)

        #expect(fetched.map(\.id) == ["1"])
    }

    // See `SwiftDataLaunchLocalDataSourceTests.fetchUpcomingIncludesRowsWithinMaxAge`, only the
    // negative-maxAge case (excluded above) had a News counterpart before this.
    @Test("a row within maxAge is included in results")
    func fetchArticlesIncludesRowsWithinMaxAge() async throws {
        let dataSource = try Self.makeDataSource()
        try await dataSource.save(
            Self.makeArticle(id: "fresh"),
            fetchedAt: Date(timeIntervalSinceNow: -1000)
        )

        let fetched = try await dataSource.fetchArticles(query: NewsListQuery(), maxAge: 2000)

        #expect(fetched.map(\.id) == ["fresh"])
    }

    @Test("search text filters to articles whose title contains it, case-insensitively")
    func fetchArticlesFiltersBySearchText() async throws {
        let dataSource = try Self.makeDataSource()
        try await dataSource.save([
            Self.makeArticle(id: "1", title: "Starship Update"),
            Self.makeArticle(id: "2", title: "Falcon 9 Launch"),
        ], fetchedAt: .now)

        let fetched = try await dataSource.fetchArticles(
            query: NewsListQuery(searchText: "starship"),
            maxAge: nil
        )

        #expect(fetched.map(\.id) == ["1"])
    }

    // See `SwiftDataLaunchLocalDataSourceTests.fetchUpcomingSearchTextWithNoMatchesReturnsEmpty`.
    @Test("search text with no matches returns an empty result, not every row")
    func fetchArticlesSearchTextWithNoMatchesReturnsEmpty() async throws {
        let dataSource = try Self.makeDataSource()
        try await dataSource.save([Self.makeArticle(id: "1", title: "Starship Update")], fetchedAt: .now)

        let fetched = try await dataSource.fetchArticles(
            query: NewsListQuery(searchText: "artemis"),
            maxAge: nil
        )

        #expect(fetched.isEmpty)
    }

    @Test("fetchArticleDetail returns nil when no row matches the id")
    func fetchArticleDetailReturnsNilForUnknownID() async throws {
        let dataSource = try Self.makeDataSource()

        let fetched = try await dataSource.fetchArticleDetail(id: "missing", maxAge: nil)

        #expect(fetched == nil)
    }

    @Test("fetchRelatedArticles returns only articles referencing the given launch id")
    func fetchRelatedArticlesFiltersByLaunchID() async throws {
        let dataSource = try Self.makeDataSource()
        try await dataSource.save([
            Self.makeArticle(id: "1", relatedLaunchIDs: ["launch-1"]),
            Self.makeArticle(id: "2", relatedLaunchIDs: ["launch-2"]),
            Self.makeArticle(id: "3", relatedLaunchIDs: ["launch-1", "launch-2"]),
        ], fetchedAt: .now)

        let fetched = try await dataSource.fetchRelatedArticles(launchID: "launch-1", limit: 10, maxAge: nil)

        #expect(Set(fetched.map(\.id)) == ["1", "3"])
    }

    @Test("fetchRelatedArticles respects the limit")
    func fetchRelatedArticlesRespectsLimit() async throws {
        let dataSource = try Self.makeDataSource()
        let articles = (1 ... 5).map {
            Self.makeArticle(id: "\($0)", relatedLaunchIDs: ["launch-1"])
        }
        try await dataSource.save(articles, fetchedAt: .now)

        let fetched = try await dataSource.fetchRelatedArticles(launchID: "launch-1", limit: 2, maxAge: nil)

        #expect(fetched.count == 2)
    }

    @Test("a row far older than any maxAge is eventually pruned from disk, not just hidden from queries")
    func savePeriodicallyPrunesVeryStaleRows() async throws {
        let dataSource = try Self.makeDataSource()
        let ancientFetchDate = Date().addingTimeInterval(-60 * 60 * 24 * 31) // 31 days ago
        try await dataSource.save(Self.makeArticle(id: "ancient"), fetchedAt: ancientFetchDate)

        let beforePrune = try await dataSource.fetchArticleDetail(id: "ancient", maxAge: nil)
        #expect(beforePrune != nil)

        // Pruning runs every 25 `save` calls; the "ancient" save above was the 1st, so 24 more
        // trigger it on the 25th.
        for index in 0 ..< 24 {
            try await dataSource.save(Self.makeArticle(id: "filler-\(index)"), fetchedAt: .now)
        }

        let afterPrune = try await dataSource.fetchArticleDetail(id: "ancient", maxAge: nil)
        #expect(afterPrune == nil)
    }
}

private extension SwiftDataNewsLocalDataSourceTests {
    static func makeDataSource() throws -> SwiftDataNewsLocalDataSource {
        let schema = Schema([NewsArticleLocalModel.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        // See `SwiftDataLaunchLocalDataSourceTests.makeDataSource`, an isolated suite, not
        // `.standard`, so the persisted `lastPruneDate` can't leak between test runs.
        let userDefaults = UserDefaults(suiteName: UUID().uuidString)!
        return SwiftDataNewsLocalDataSource(container: container, userDefaults: userDefaults)
    }

    static func makeArticle(id: String,
                            title: String = "Mission",
                            publishedAt: Date = Date(timeIntervalSince1970: 1000),
                            relatedLaunchIDs: [String] = []) -> NewsArticle
    {
        NewsArticle(
            id: id,
            title: title,
            summary: "Summary",
            url: URL(string: "https://example.com/\(id)")!,
            imageURL: nil,
            newsSite: "SpaceNews",
            publishedAt: publishedAt,
            relatedLaunchIDs: relatedLaunchIDs
        )
    }
}

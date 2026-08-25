//
//  NewsLocalDataSource.swift
//  TMinus
//
//  Created by Sadegh on 13/08/2026.
//

import Foundation
import SwiftData

// MARK: - NewsLocalDataSource

protocol NewsLocalDataSource: Sendable {
    func fetchArticles(query: NewsListQuery, maxAge: TimeInterval?) async throws -> [NewsArticle]
    func fetchArticleDetail(id: String, maxAge: TimeInterval?) async throws -> NewsArticle?
    func fetchRelatedArticles(launchID: String, limit: Int, maxAge: TimeInterval?) async throws -> [NewsArticle]
    func save(_ articles: [NewsArticle], fetchedAt: Date) async throws
    func save(_ article: NewsArticle, fetchedAt: Date) async throws
}

// MARK: - SwiftDataNewsLocalDataSource

/// Mirrors `SwiftDataLaunchLocalDataSource`, same `actor`-isolated `ModelContext`, same
/// page-1-only cache guard, same TTL-via-`maxAge` staleness model, so News gets the same offline
/// resilience Launches does instead of relying solely on the in-memory, process-lifetime
/// `DataCache`.
actor SwiftDataNewsLocalDataSource: NewsLocalDataSource {
    private let container: ModelContainer
    private var context: ModelContext
    private let userDefaults: UserDefaults
    /// See `SwiftDataLaunchLocalDataSource`'s equivalent, bounds on-disk growth without pruning
    /// on every save.
    private var savesSinceLastPrune = 0

    init(container: ModelContainer, userDefaults: UserDefaults = .standard) {
        self.container = container
        self.userDefaults = userDefaults
        context = ModelContext(container)
    }

    /// See `SwiftDataLaunchLocalDataSource`'s equivalent, persisted so the time-based prune
    /// trigger below survives across app launches, unlike `savesSinceLastPrune`.
    private var lastPruneDate: Date {
        get {
            guard let interval = userDefaults.object(forKey: Constants.lastPruneDateKey) as? Double else {
                let now = Date()
                userDefaults.set(now.timeIntervalSince1970, forKey: Constants.lastPruneDateKey)
                return now
            }
            return Date(timeIntervalSince1970: interval)
        }
        set {
            userDefaults.set(newValue.timeIntervalSince1970, forKey: Constants.lastPruneDateKey)
        }
    }

    func fetchArticles(query: NewsListQuery, maxAge: TimeInterval?) async throws -> [NewsArticle] {
        // See `SwiftDataLaunchLocalDataSource.fetchUpcomingLaunches`, offset/limit paging isn't
        // stable under concurrent writes, so only page 1 is ever served from the cache.
        guard query.page == 1 else { return [] }

        let cutoff = cutoffDate(maxAge: maxAge)
        let searchText = query.searchText?.localizedLowercase

        var descriptor = FetchDescriptor<NewsArticleLocalModel>(
            predicate: #Predicate<NewsArticleLocalModel> { $0.fetchedAt >= cutoff },
            // `id` is a secondary tie-breaker, see `SwiftDataLaunchLocalDataSource`'s equivalent
            // for why: two articles sharing the exact same `publishedAt` would otherwise have no
            // guaranteed stable order across separate fetches of the same page.
            sortBy: [SortDescriptor(\.publishedAt, order: .reverse), SortDescriptor(\.id)]
        )
        let offset = max((query.page - 1) * query.limit, 0)
        let limit = max(query.limit, 1)
        let hasSearchText = searchText.map { $0.isEmpty == false } ?? false
        if hasSearchText == false {
            // See `SwiftDataLaunchLocalDataSource.fetchLaunches`, no post-fetch filtering
            // happens below in this case, so the DB fetch can be capped at exactly what
            // `offset`/`limit` will ever use instead of pulling every cached row into memory
            // on every plain list load.
            descriptor.fetchLimit = offset + limit
        }
        let models = try context.fetch(descriptor)

        // `searchText` is deliberately never folded into the `#Predicate`, see
        // `SwiftDataLaunchLocalDataSource.fetchLaunches` for why any string-containment operator
        // in a SwiftData `#Predicate` is avoided entirely (a real, reproducible CoreData/SQLite
        // crash under concurrent fetches, independent of which Swift string method is used).
        let matching: [NewsArticleLocalModel]
        if let searchText, searchText.isEmpty == false {
            matching = models.filter { $0.titleLowercased.contains(searchText) }
        } else {
            matching = models
        }

        // Mapped *before* slicing: `NewsLocalModelMapper.map` is failable (an unparseable
        // persisted `urlString`, which shouldn't happen but isn't provably impossible), and
        // slicing first would let one unmappable row inside the slice quietly shrink a page
        // below `limit` even though enough matching rows exist beyond it, which `NewsRepository
        // .pagedResult`'s "a full page implies more to load" heuristic would then misread as
        // "no more pages," ending pagination one page early.
        let articles = matching.compactMap(NewsLocalModelMapper.map(_:))
        guard offset < articles.count else { return [] }
        return Array(articles[offset...].prefix(limit))
    }

    func fetchArticleDetail(id: String, maxAge: TimeInterval?) async throws -> NewsArticle? {
        let cutoff = cutoffDate(maxAge: maxAge)
        var descriptor = FetchDescriptor<NewsArticleLocalModel>(
            predicate: #Predicate<NewsArticleLocalModel> { $0.id == id && $0.fetchedAt >= cutoff }
        )
        descriptor.fetchLimit = 1
        guard let model = try context.fetch(descriptor).first else { return nil }
        return NewsLocalModelMapper.map(model)
    }

    func fetchRelatedArticles(launchID: String, limit: Int, maxAge: TimeInterval?) async throws -> [NewsArticle] {
        let cutoff = cutoffDate(maxAge: maxAge)
        // As in `fetchArticles`: the `relatedLaunchIDs.contains(launchID)` membership check is
        // done in Swift after the fetch rather than in the `#Predicate`, to stay well clear of
        // any CoreData/SQLite predicate-translation path that touches the same crash-prone
        // machinery as string search.
        let descriptor = FetchDescriptor<NewsArticleLocalModel>(
            predicate: #Predicate<NewsArticleLocalModel> { $0.fetchedAt >= cutoff },
            // `id` is a secondary tie-breaker, see `SwiftDataLaunchLocalDataSource`'s equivalent
            // for why: two articles sharing the exact same `publishedAt` would otherwise have no
            // guaranteed stable order across separate fetches of the same page.
            sortBy: [SortDescriptor(\.publishedAt, order: .reverse), SortDescriptor(\.id)]
        )
        // Unlike `fetchArticles`, this can't cap the fetch at exactly `limit`, the
        // `relatedLaunchIDs.contains(launchID)` filter below runs in Swift, so the DB can't know
        // in advance how many rows will match. Deliberately left unbounded by anything beyond
        // `cutoff` (rather than capped at a multiple of `limit`, as this used to be): a launch's
        // related articles are picked by `relatedLaunchIDs`, not recency, so an older article can
        // easily fall outside any recency-based cap even though it's still cached and still
        // related, that cap silently under-fetched real matches once the article cache
        // accumulated enough unrelated, more-recent articles. Correctness wins here over the
        // extra fetch cost: `cutoff`/the 30-day prune window (`pruneIfDue`) already bound how much
        // this can ever pull in, and this query only runs once per launch-detail visit, not on
        // every list scroll.
        let models = try context.fetch(descriptor)
        let matching = models.filter { $0.relatedLaunchIDs.contains(launchID) }
        // See `fetchArticles`, mapped before slicing, for the same reason.
        return Array(matching.compactMap(NewsLocalModelMapper.map(_:)).prefix(max(limit, 1)))
    }

    func save(_ articles: [NewsArticle], fetchedAt: Date) async throws {
        // See `SwiftDataLaunchLocalDataSource.save(_:fetchedAt:)`, one batch fetch instead of
        // one per article.
        var existingByID = try fetchModels(ids: Set(articles.map(\.id)))

        for article in articles {
            if let existing = existingByID[article.id] {
                NewsLocalModelMapper.update(existing, from: article, fetchedAt: fetchedAt)
            } else {
                let model = NewsLocalModelMapper.map(article, fetchedAt: fetchedAt)
                context.insert(model)
                existingByID[article.id] = model
            }
        }
        try saveContext()
        try pruneIfDue()
    }

    func save(_ article: NewsArticle, fetchedAt: Date) async throws {
        if let existing = try fetchModel(id: article.id) {
            NewsLocalModelMapper.update(existing, from: article, fetchedAt: fetchedAt)
        } else {
            context.insert(NewsLocalModelMapper.map(article, fetchedAt: fetchedAt))
        }
        try saveContext()
        try pruneIfDue()
    }
}

private extension SwiftDataNewsLocalDataSource {
    /// See `SwiftDataLaunchLocalDataSource.saveContext`, rolls back the actor's long-lived
    /// context on a failed save so uncommitted changes don't bleed into later fetches/saves.
    func saveContext() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    func cutoffDate(maxAge: TimeInterval?) -> Date {
        guard let maxAge else { return .distantPast }
        return Date().addingTimeInterval(-maxAge)
    }

    func fetchModel(id: String) throws -> NewsArticleLocalModel? {
        var descriptor = FetchDescriptor<NewsArticleLocalModel>(
            predicate: #Predicate<NewsArticleLocalModel> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func fetchModels(ids: Set<String>) throws -> [String: NewsArticleLocalModel] {
        guard ids.isEmpty == false else { return [:] }
        let descriptor = FetchDescriptor<NewsArticleLocalModel>(
            predicate: #Predicate<NewsArticleLocalModel> { ids.contains($0.id) }
        )
        let models = try context.fetch(descriptor)
        return Dictionary(models.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
    }

    /// See `SwiftDataLaunchLocalDataSource.pruneIfDue`, same rationale and thresholds, including
    /// replacing `context` on the same cadence.
    func pruneIfDue() throws {
        savesSinceLastPrune += 1
        let dueByCount = savesSinceLastPrune >= Constants.pruneInterval
        let dueByTime = Date().timeIntervalSince(lastPruneDate) >= Constants.pruneTimeInterval
        guard dueByCount || dueByTime else { return }
        savesSinceLastPrune = 0
        lastPruneDate = Date()

        let cutoff = Date().addingTimeInterval(-Constants.retentionWindow)
        try context.delete(model: NewsArticleLocalModel.self, where: #Predicate { $0.fetchedAt < cutoff })

        // This actor's `ModelContext` (see `init`) would otherwise be held for the app's entire
        // lifetime, and every object it has ever fetched or inserted stays registered in its
        // identity map even after nothing else references it, `rollback()` in `saveContext()`
        // only discards *uncommitted* changes, never this accumulated registration. `ModelContext`
        // has no public reset/clear operation (unlike Core Data's `NSManagedObjectContext.reset()`),
        // so the only way to actually drop that accumulated registration is to replace the context
        // itself. Safe to do here specifically: this is always reached immediately after a
        // successful `saveContext()`, so there's nothing uncommitted to lose, and every caller
        // already receives a plain `NewsArticle` value type back, never a still-referenced
        // `NewsArticleLocalModel` tied to the old context.
        context = ModelContext(container)
    }
}

// MARK: - Constants

private extension SwiftDataNewsLocalDataSource {
    enum Constants {
        static let pruneInterval = 25
        /// See `SwiftDataLaunchLocalDataSource`'s equivalent, backstops the count-based trigger
        /// for a session too short/infrequent to ever accumulate `pruneInterval` saves.
        static let pruneTimeInterval: TimeInterval = 60 * 60 * 24
        static let lastPruneDateKey = "SwiftDataNewsLocalDataSource.lastPruneDate"
        static let retentionWindow: TimeInterval = 60 * 60 * 24 * 30
    }
}

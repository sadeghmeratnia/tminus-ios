//
//  LaunchLocalDataSource.swift
//  TMinus
//
//  Created by Sadegh on 19/05/2026.
//

import Foundation
import SwiftData

// MARK: - LaunchLocalDataSource

protocol LaunchLocalDataSource: Sendable {
    func fetchUpcomingLaunches(query: LaunchListQuery, maxAge: TimeInterval?) async throws -> [Launch]
    func fetchPreviousLaunches(query: LaunchListQuery, maxAge: TimeInterval?) async throws -> [Launch]
    func fetchLaunchDetail(id: String, maxAge: TimeInterval?) async throws -> Launch?
    func save(_ launches: [Launch], fetchedAt: Date) async throws
    func save(_ launch: Launch, fetchedAt: Date) async throws
}

// MARK: - SwiftDataLaunchLocalDataSource

actor SwiftDataLaunchLocalDataSource: LaunchLocalDataSource {
    private let container: ModelContainer
    private var context: ModelContext
    private let userDefaults: UserDefaults
    /// Staleness is otherwise only enforced at query time (`maxAge`/`cutoffDate`), which hides
    /// an expired row from reads but never removes it, left unchecked, the store grows by every
    /// launch ever fetched for the life of the install. Counted rather than pruned on every save
    /// so this stays a cheap, infrequent maintenance pass rather than overhead on the hot path.
    ///
    /// In-memory only (unlike `lastPruneDate` below), under-counting across a relaunch just means
    /// a few more `save` calls before the count-based trigger fires again, which the time-based
    /// trigger backstops regardless.
    private var savesSinceLastPrune = 0

    init(container: ModelContainer, userDefaults: UserDefaults = .standard) {
        self.container = container
        self.userDefaults = userDefaults
        context = ModelContext(container)
    }

    /// Persisted (unlike `savesSinceLastPrune`) specifically so pruning still eventually runs for
    /// a typical session: this actor, and its save counter, is recreated fresh every app launch,
    /// so a session that never performs `Constants.pruneInterval` saves before backgrounding would
    /// otherwise never prune at all, no matter how many such sessions accumulate. Falls back to
    /// "now" when never set (a fresh install), so the very first session doesn't immediately count
    /// as overdue.
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

    func fetchUpcomingLaunches(query: LaunchListQuery, maxAge: TimeInterval?) async throws -> [Launch] {
        // A concurrent save can shift offset-based cache pages and skip rows. Only page 1 is
        // served locally; later pages always come from the network.
        guard query.page == 1 else { return [] }

        let now = Date()
        let cutoff = cutoffDate(maxAge: maxAge)
        let searchText = query.searchText?.localizedLowercase
        // Match the API's status-based split. Unknown statuses fall back to the launch window so
        // completed launches do not remain in Upcoming forever.
        let resolvedStatusCodes = LaunchLocalModelMapper.resolvedStatusCodes
        let unknownStatusCode = LaunchLocalModelMapper.unknownStatusCode

        let predicate = #Predicate<LaunchLocalModel> {
            !resolvedStatusCodes.contains($0.statusCode)
                && ($0.statusCode != unknownStatusCode || $0.windowStart >= now)
                && $0.fetchedAt >= cutoff
        }

        return try fetchLaunches(
            query: query,
            searchText: searchText,
            predicate: predicate,
            // `id` is a secondary tie-breaker, not just `windowStart`, two launches sharing the
            // exact same window start (e.g. co-manifested payloads) would otherwise have no
            // guaranteed stable order across separate fetches of the same page, since neither
            // SQLite nor SwiftData promises a stable tie-break order on its own; without one, the
            // set of tied rows straddling `fetchLimit`'s cutoff could differ between two identical
            // queries, reading to the user as items silently appearing/disappearing.
            sortBy: [SortDescriptor(\LaunchLocalModel.windowStart, order: .forward), SortDescriptor(\LaunchLocalModel.id)]
        )
    }

    func fetchPreviousLaunches(query: LaunchListQuery, maxAge: TimeInterval?) async throws -> [Launch] {
        // See `fetchUpcomingLaunches`, same page-1-only guard, for the same reason.
        guard query.page == 1 else { return [] }

        let now = Date()
        let cutoff = cutoffDate(maxAge: maxAge)
        let searchText = query.searchText?.localizedLowercase
        // Mirror image of `fetchUpcomingLaunches`'s predicate: resolved statuses are always
        // previous, and an unrecognized status whose window has already passed is presumed
        // resolved too, see `fetchUpcomingLaunches` for why this keeps the split exhaustive and
        // non-overlapping.
        let resolvedStatusCodes = LaunchLocalModelMapper.resolvedStatusCodes
        let unknownStatusCode = LaunchLocalModelMapper.unknownStatusCode

        let predicate = #Predicate<LaunchLocalModel> {
            (resolvedStatusCodes.contains($0.statusCode)
                || ($0.statusCode == unknownStatusCode && $0.windowStart < now))
                && $0.fetchedAt >= cutoff
        }

        return try fetchLaunches(
            query: query,
            searchText: searchText,
            predicate: predicate,
            // See `fetchUpcomingLaunches`, same `id` tie-breaker, same reason.
            sortBy: [SortDescriptor(\LaunchLocalModel.windowStart, order: .reverse), SortDescriptor(\LaunchLocalModel.id)]
        )
    }

    func fetchLaunchDetail(id: String, maxAge: TimeInterval?) async throws -> Launch? {
        let cutoff = cutoffDate(maxAge: maxAge)
        var descriptor = FetchDescriptor<LaunchLocalModel>(
            predicate: #Predicate<LaunchLocalModel> {
                $0.id == id && $0.fetchedAt >= cutoff
            }
        )
        descriptor.fetchLimit = 1
        guard let model = try context.fetch(descriptor).first else {
            return nil
        }
        return LaunchLocalModelMapper.map(model)
    }

    func save(_ launches: [Launch], fetchedAt: Date) async throws {
        // One batch fetch for all existing rows instead of one fetch per launch, so saving a
        // page of N launches costs a single query rather than N. Mutated in place as we iterate
        // so a duplicate id within the same batch is treated as an update to the row just
        // inserted/updated in this loop, not a second insert of the same id.
        var existingByID = try fetchModels(ids: Set(launches.map(\.id)))

        for launch in launches {
            if let existing = existingByID[launch.id] {
                LaunchLocalModelMapper.update(existing, from: launch, fetchedAt: fetchedAt)
            } else {
                let model = LaunchLocalModelMapper.map(launch, fetchedAt: fetchedAt)
                context.insert(model)
                existingByID[launch.id] = model
            }
        }
        try saveContext()
        try pruneIfDue()
    }

    func save(_ launch: Launch, fetchedAt: Date) async throws {
        try upsert(launch, fetchedAt: fetchedAt)
        try saveContext()
        try pruneIfDue()
    }
}

extension SwiftDataLaunchLocalDataSource {
    /// `searchText` is deliberately never folded into the `#Predicate` itself (as a
    /// `.contains`/`.localizedStandardContains` clause), any string-containment operator in a
    /// SwiftData `#Predicate` compiles to a CoreData/SQLite fetch that runs through
    /// `_NSCoreDataStringSearch`, which has a real, reproducible SIGSEGV under concurrent fetches
    /// (confirmed via crash reports during this app's own test suite, independent of which Swift
    /// string method was used). Filtering in Swift after the fetch avoids that code path
    /// entirely; the local cache's result set is always small enough (a page's worth of recent
    /// launches) for this to cost nothing that matters.
    private func fetchLaunches(query: LaunchListQuery,
                               searchText: String?,
                               predicate: Predicate<LaunchLocalModel>,
                               sortBy: [SortDescriptor<LaunchLocalModel>]) throws -> [Launch]
    {
        // Every caller already guards `query.page == 1` before reaching here (see
        // `fetchUpcomingLaunches`/`fetchPreviousLaunches`), so `offset` below is provably always
        // `0`. It's computed generically anyway rather than hardcoded to `0` so this stays
        // correct, not silently wrong, if that guard is ever relaxed; this assertion is what
        // actually enforces the invariant it relies on in the meantime.
        assert(query.page == 1, "SwiftDataLaunchLocalDataSource only serves page 1 from cache")
        let offset = max((query.page - 1) * query.limit, 0)
        let limit = max(query.limit, 1)

        var descriptor = FetchDescriptor<LaunchLocalModel>(predicate: predicate, sortBy: sortBy)
        let hasSearchText = searchText.map { $0.isEmpty == false } ?? false
        if hasSearchText == false {
            // No post-fetch filtering happens below in this case, so the DB fetch itself can be
            // capped at exactly what `offset`/`limit` will ever use, without this, every cached
            // row in the partition (bounded only by the 30-day prune window, not by `query.limit`)
            // gets pulled into memory on every list load. When a search is active, filtering
            // happens in Swift *after* the fetch (see the comment below), so the full candidate
            // set is still needed here.
            descriptor.fetchLimit = offset + limit
        }
        let models = try context.fetch(descriptor)

        let matching: [LaunchLocalModel]
        if let searchText, searchText.isEmpty == false {
            matching = models.filter { $0.nameLowercased.contains(searchText) }
        } else {
            matching = models
        }

        guard offset < matching.count else { return [] }
        return matching[offset...].prefix(limit).map(LaunchLocalModelMapper.map(_:))
    }

    /// This actor's `ModelContext` is held for the app's entire lifetime (see `init`), so a
    /// failed `save()` must not leave its uncommitted inserts/updates registered in the context,
    /// left unrolled-back, they'd bleed into every subsequent fetch and save on this same
    /// context. `rollback()` discards exactly that in-flight change set.
    private func saveContext() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private func cutoffDate(maxAge: TimeInterval?) -> Date {
        guard let maxAge else { return .distantPast }
        return Date().addingTimeInterval(-maxAge)
    }

    private func upsert(_ launch: Launch, fetchedAt: Date) throws {
        if let existing = try fetchModel(id: launch.id) {
            LaunchLocalModelMapper.update(existing, from: launch, fetchedAt: fetchedAt)
            return
        }

        let model = LaunchLocalModelMapper.map(launch, fetchedAt: fetchedAt)
        context.insert(model)
    }

    private func fetchModel(id: String) throws -> LaunchLocalModel? {
        var descriptor = FetchDescriptor<LaunchLocalModel>(
            predicate: #Predicate<LaunchLocalModel> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Batch equivalent of `fetchModel(id:)`, one query for all ids instead of one query each.
    private func fetchModels(ids: Set<String>) throws -> [String: LaunchLocalModel] {
        guard ids.isEmpty == false else { return [:] }
        let descriptor = FetchDescriptor<LaunchLocalModel>(
            predicate: #Predicate<LaunchLocalModel> { ids.contains($0.id) }
        )
        let models = try context.fetch(descriptor)
        // uniquingKeysWith rather than uniqueKeysWithValues: if the store ever already has two
        // rows sharing an id (e.g. from data created before this method existed), this must not
        // crash, last-one-wins is an acceptable degradation for a cache, not corruption.
        return Dictionary(models.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
    }

    /// Deletes rows old enough that no `maxAge` any caller actually uses could still consider
    /// them fresh, `Constants.retentionWindow` is deliberately far beyond the longest TTL
    /// (`LaunchCacheTTL.previous`), so this only ever removes rows that were already unreachable
    /// through every read path, never something a slightly-stale-but-still-useful query wanted.
    private func pruneIfDue() throws {
        savesSinceLastPrune += 1
        let dueByCount = savesSinceLastPrune >= Constants.pruneInterval
        let dueByTime = Date().timeIntervalSince(lastPruneDate) >= Constants.pruneTimeInterval
        guard dueByCount || dueByTime else { return }
        savesSinceLastPrune = 0
        lastPruneDate = Date()

        let cutoff = Date().addingTimeInterval(-Constants.retentionWindow)
        try context.delete(model: LaunchLocalModel.self, where: #Predicate { $0.fetchedAt < cutoff })

        // This actor's `ModelContext` (see `init`) would otherwise be held for the app's entire
        // lifetime, and every object it has ever fetched or inserted stays registered in its
        // identity map even after nothing else references it, `rollback()` in `saveContext()`
        // only discards *uncommitted* changes, never this accumulated registration. `ModelContext`
        // has no public reset/clear operation (unlike Core Data's `NSManagedObjectContext.reset()`),
        // so the only way to actually drop that accumulated registration is to replace the context
        // itself. Safe to do here specifically: this is always reached immediately after a
        // successful `saveContext()`, so there's nothing uncommitted to lose, and every caller
        // already receives a plain `Launch` value type back, never a still-referenced
        // `LaunchLocalModel` tied to the old context.
        context = ModelContext(container)
    }
}

// MARK: - Constants

private extension SwiftDataLaunchLocalDataSource {
    enum Constants {
        /// How many `save` calls accumulate before a prune pass runs.
        static let pruneInterval = 25
        /// Backstops the count-based trigger above: this actor (and `savesSinceLastPrune`) is
        /// recreated fresh every app launch, so a typical short/infrequent session might never
        /// accumulate `pruneInterval` saves before backgrounding, without a time-based trigger
        /// too, pruning would then never run at all, no matter how many such sessions accumulate.
        static let pruneTimeInterval: TimeInterval = 60 * 60 * 24
        static let lastPruneDateKey = "SwiftDataLaunchLocalDataSource.lastPruneDate"
        /// Rows older than this are unreachable through any current read path regardless of
        /// `maxAge` (30 days, versus `LaunchCacheTTL.previous`'s 900 seconds), so pruning them is
        /// safe.
        static let retentionWindow: TimeInterval = 60 * 60 * 24 * 30
    }
}

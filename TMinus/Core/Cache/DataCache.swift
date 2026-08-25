//
//  DataCache.swift
//  TMinus
//
//  Created by Sadegh on 22/04/2026.
//

import Foundation

// MARK: - DataCaching

/// Narrow read/write surface `URLSessionNetworkClient` actually depends on, split out from the
/// concrete `DataCache` actor so tests can substitute a spy/stub without driving `NSCache`'s real
/// eviction timing. `DataCache` conforms below; `AppContainer` still hands out the concrete type
/// (it also needs `removeStaleEntries()`, which stays out of this narrower protocol).
protocol DataCaching: Sendable {
    func set(_ data: Data, for key: String, ttl: TimeInterval?, source: DataCache.DataSource) async
    func cachedValue(for key: String, allowingStale: Bool) async -> DataCache.CachedValue?
}

extension DataCaching {
    /// Protocol requirements can't declare default argument values directly, this lower-arity
    /// overload is the standard workaround, mirroring `DataCache.cachedValue`'s own default.
    func cachedValue(for key: String) async -> DataCache.CachedValue? {
        await cachedValue(for: key, allowingStale: false)
    }
}

// MARK: - DataCache

actor DataCache {
    private enum Defaults {
        static let cacheCountLimit = 512
        /// Matches `cacheCountLimit`: this is the point at which `knownKeys` triggers an
        /// opportunistic sweep of entries `NSCache` has already dropped on its own (eviction under
        /// `countLimit`/`totalCostLimit` pressure). A materially higher threshold than the cache's
        /// own entry-count ceiling would let `knownKeys` accumulate dead keys for far longer than
        /// the cache could ever actually hold live entries before a sweep ever prunes them.
        static let keyCompactionThreshold = cacheCountLimit
        /// `NSCache.countLimit` alone caps *how many* responses are cached, not their combined
        /// size, a handful of unusually large payloads could still dominate memory despite a
        /// "512 entries" ceiling looking safe. `totalCostLimit`, paired with `set`'s `cost:`
        /// (the response's byte count), gives `NSCache` the actual size signal it needs to evict
        /// under real memory pressure instead of only under entry-count pressure.
        static let totalCostByteLimit = 25 * 1024 * 1024
    }

    /// Only `.network` is ever constructed today, `URLSessionNetworkClient` is this cache's sole
    /// writer. Kept as a case-bearing enum (rather than dropped in favor of a bare `Metadata`
    /// without a `source` field) since `Metadata.source` is still useful debugging/logging
    /// context, but trimmed to the one case actually in use rather than declaring `.disk`/
    /// `.memory` tiers this cache doesn't implement.
    enum DataSource: Equatable {
        case network
    }

    struct Metadata: Equatable {
        let fetchedAt: Date
        let ttl: TimeInterval
        let source: DataSource

        var expiryDate: Date {
            fetchedAt.addingTimeInterval(ttl)
        }

        var isStale: Bool {
            expiryDate <= Date()
        }
    }

    struct CachedValue: Equatable {
        let data: Data
        let metadata: Metadata
    }

    private final class CacheEntry {
        let data: Data
        let metadata: Metadata

        init(data: Data, metadata: Metadata) {
            self.data = data
            self.metadata = metadata
        }
    }

    private let cache = NSCache<NSString, CacheEntry>()
    private var knownKeys: Set<String> = []
    private let ttl: TimeInterval
    private let keyCompactionThreshold: Int
    /// Guards against scheduling a pile-up of redundant sweep tasks: while an opportunistic sweep
    /// is already pending/running, further `set` calls that also cross the threshold shouldn't
    /// each queue their own.
    private var isSweepScheduled = false
    /// Defaults to the real wall clock; tests inject a controllable closure instead of relying on
    /// `Task.sleep` past a real TTL to observe expiry, which is inherently timing-flaky (a
    /// scheduler hiccup near the boundary flips the assertion either way).
    private let now: @Sendable () -> Date

    init(ttl: TimeInterval = 300,
         countLimit: Int = Defaults.cacheCountLimit,
         totalCostByteLimit: Int = Defaults.totalCostByteLimit,
         keyCompactionThreshold: Int = Defaults.keyCompactionThreshold,
         now: @escaping @Sendable () -> Date = Date.init)
    {
        self.ttl = ttl
        self.keyCompactionThreshold = max(1, keyCompactionThreshold)
        self.now = now
        cache.countLimit = max(1, countLimit)
        cache.totalCostLimit = max(1, totalCostByteLimit)
    }

    func set(_ data: Data,
             for key: String,
             ttl: TimeInterval? = nil,
             source: DataSource = .network)
    {
        let effectiveTTL = ttl ?? self.ttl
        let metadata = Metadata(
            fetchedAt: now(),
            ttl: effectiveTTL,
            source: source
        )
        // `cost:` is the entry's byte size, so `totalCostLimit` evictions are driven by actual
        // memory footprint rather than entry count alone.
        cache.setObject(CacheEntry(data: data, metadata: metadata), forKey: key as NSString, cost: data.count)
        knownKeys.insert(key)
        sweepIfNeeded()
    }

    func cachedValue(for key: String, allowingStale: Bool = false) -> CachedValue? {
        guard let entry = cache.object(forKey: key as NSString) else { return nil }
        if isStale(entry.metadata), allowingStale == false {
            return nil
        }
        return CachedValue(data: entry.data, metadata: entry.metadata)
    }

    /// Checked against the injected clock rather than `Metadata.isStale` (which always reads the
    /// real wall clock), this is the one place staleness actually gates behavior (eviction,
    /// cache-hit/miss), so it's the one place that needs to agree with a test's injected `now`.
    private func isStale(_ metadata: Metadata) -> Bool {
        metadata.expiryDate <= now()
    }

    func metadata(for key: String) -> Metadata? {
        cache.object(forKey: key as NSString)?.metadata
    }

    /// Explicit full sweep, called on the app's background scene-phase transition, so a session
    /// backgrounded for a while doesn't resume with a cache full of entries nobody's read since
    /// they expired.
    func removeStaleEntries() {
        sweep()
    }

    /// Runs the same stale-eviction `removeStaleEntries()` performs, but opportunistically,
    /// piggybacked on `set(_:for:ttl:source:)` once `knownKeys` crosses `keyCompactionThreshold`,
    /// so a long-lived foreground session that never backgrounds still has stale entries evicted
    /// periodically, driven by cache activity rather than solely by app lifecycle events.
    ///
    /// Scheduled as a separate `Task` rather than run inline: `DataCache` is a single actor
    /// serializing every cache read/write app-wide, so an inline O(`keyCompactionThreshold`) scan
    /// would make this particular `set` call, and every other caller queued behind this actor,
    /// pay for the sweep's latency. Deferring it to its own `Task` lets `set` return immediately
    /// and lets the sweep run as its own actor-isolated unit of work instead.
    private func sweepIfNeeded() {
        guard knownKeys.count >= keyCompactionThreshold, isSweepScheduled == false else { return }
        isSweepScheduled = true
        Task { [weak self] in
            await self?.performScheduledSweep()
        }
    }

    private func performScheduledSweep() {
        isSweepScheduled = false
        sweep()
    }

    private func sweep() {
        for key in knownKeys {
            guard let metadata = cache.object(forKey: key as NSString)?.metadata, isStale(metadata) else { continue }
            cache.removeObject(forKey: key as NSString)
        }
        // Drops both keys just evicted above and keys `NSCache` already evicted on its own
        // (e.g. under memory pressure), so `knownKeys` never grows unbounded relative to what's
        // actually still cached.
        knownKeys = Set(knownKeys.filter { cache.object(forKey: $0 as NSString) != nil })
    }
}

// MARK: - DataCaching

extension DataCache: DataCaching {}

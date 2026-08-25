//
//  DataCacheTests.swift
//  TMinusTests
//
//  Created by Sadegh on 19/05/2026.
//

import Foundation
import Testing
@testable import TMinus

/// Mutable box handed to `DataCache(now:)` so tests can move the cache's clock forward
/// deterministically instead of sleeping past a real TTL, a real-sleep boundary check is
/// inherently timing-flaky (a scheduler hiccup near the edge flips the assertion either way).
private final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(_ date: Date = Date()) {
        current = date
    }

    func advance(by seconds: TimeInterval) {
        lock.lock()
        current = current.addingTimeInterval(seconds)
        lock.unlock()
    }

    func now() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return current
    }
}

@Suite("DataCache")
enum DataCacheTests {
    @Test("Stores metadata for cache entry")
    static func storesMetadata() async {
        let cache = DataCache(ttl: 60)
        let key = "launches/upcoming"
        let payload = Data("value".utf8)

        await cache.set(payload, for: key, ttl: 120, source: .network)
        let cachedValue = await cache.cachedValue(for: key)

        #expect(cachedValue?.data == payload)
        #expect(cachedValue?.metadata.ttl == 120)
        #expect(cachedValue?.metadata.source == .network)
        #expect(cachedValue?.metadata.isStale == false)
    }

    @Test("Stale entries are hidden by default but available when requested")
    static func staleEntryBehavior() async throws {
        let clock = TestClock()
        let cache = DataCache(ttl: 10, now: clock.now)
        let key = "launches/previous"
        let payload = Data("old".utf8)

        await cache.set(payload, for: key, source: .network)
        clock.advance(by: 11)

        let strictValue = await cache.cachedValue(for: key)
        let staleValue = await cache.cachedValue(for: key, allowingStale: true)

        #expect(strictValue == nil)
        #expect(staleValue?.data == payload)
    }

    @Test("removeStaleEntries clears expired cache entries")
    static func removeStaleEntries() async throws {
        let clock = TestClock()
        let cache = DataCache(ttl: 1, now: clock.now)
        let staleKey = "stale"
        let freshKey = "fresh"

        await cache.set(Data("stale".utf8), for: staleKey, ttl: 10, source: .network)
        await cache.set(Data("fresh".utf8), for: freshKey, ttl: 60, source: .network)
        clock.advance(by: 11)

        await cache.removeStaleEntries()

        let staleAfterCleanup = await cache.metadata(for: staleKey)
        let freshAfterCleanup = await cache.metadata(for: freshKey)

        #expect(staleAfterCleanup == nil)
        #expect(freshAfterCleanup != nil)
    }

    @Test("Crossing the key-compaction threshold opportunistically sweeps stale entries without an explicit removeStaleEntries call")
    static func opportunisticSweepEvictsStaleEntriesOnceThresholdIsCrossed() async throws {
        let clock = TestClock()
        let cache = DataCache(ttl: 60, keyCompactionThreshold: 2, now: clock.now)
        let staleKey = "stale"

        await cache.set(Data("stale".utf8), for: staleKey, ttl: 10, source: .network)
        clock.advance(by: 11)

        // This crosses `keyCompactionThreshold` (2), which should schedule an opportunistic
        // sweep on its own, no call to `removeStaleEntries()` here. The sweep itself still runs
        // as a real, independently-scheduled `Task`, so this loop polls for it rather than
        // asserting synchronously; only the staleness boundary that decides *whether* an entry
        // gets swept is made deterministic via `clock`, not the sweep's own scheduling.
        await cache.set(Data("fresh".utf8), for: "fresh", ttl: 60, source: .network)

        var staleEvicted = false
        for _ in 0 ..< 50 {
            if await cache.metadata(for: staleKey) == nil {
                staleEvicted = true
                break
            }
            try await Task.sleep(for: .milliseconds(20))
        }

        #expect(staleEvicted)
    }
}

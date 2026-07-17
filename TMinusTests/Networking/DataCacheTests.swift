//
//  DataCacheTests.swift
//  TMinusTests
//
//  Created by Sadegh on 19/05/2026.
//

import Foundation
import Testing
@testable import TMinus

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
        let cache = DataCache(ttl: 0.01)
        let key = "launches/previous"
        let payload = Data("old".utf8)

        await cache.set(payload, for: key, source: .network)
        try await Task.sleep(nanoseconds: 50_000_000)

        let strictValue = await cache.cachedValue(for: key)
        let staleValue = await cache.cachedValue(for: key, allowingStale: true)

        #expect(strictValue == nil)
        #expect(staleValue?.data == payload)
        #expect(staleValue?.metadata.isStale == true)
    }

    @Test("removeStaleEntries clears expired cache entries")
    static func removeStaleEntries() async throws {
        let cache = DataCache(ttl: 1)
        let staleKey = "stale"
        let freshKey = "fresh"

        await cache.set(Data("stale".utf8), for: staleKey, ttl: 0.01, source: .network)
        await cache.set(Data("fresh".utf8), for: freshKey, ttl: 60, source: .network)
        try await Task.sleep(nanoseconds: 50_000_000)

        await cache.removeStaleEntries()

        let staleAfterCleanup = await cache.metadata(for: staleKey)
        let freshAfterCleanup = await cache.metadata(for: freshKey)

        #expect(staleAfterCleanup == nil)
        #expect(freshAfterCleanup != nil)
        #expect(freshAfterCleanup?.isStale == false)
    }
}

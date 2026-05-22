//
//  DataCache.swift
//  TMinus
//
//  Created by Sadegh on 22/04/2026.
//

import Foundation

actor DataCache {
    private enum Defaults {
        static let cacheCountLimit = 512
        static let keyCompactionThreshold = 1024
    }

    enum DataSource: Equatable, Sendable {
        case network
        case disk
        case memory
    }

    struct Metadata: Equatable, Sendable {
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

    struct CachedValue: Equatable, Sendable {
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

    init(ttl: TimeInterval = 300,
         countLimit: Int = Defaults.cacheCountLimit,
         keyCompactionThreshold: Int = Defaults.keyCompactionThreshold) {
        self.ttl = ttl
        self.keyCompactionThreshold = max(1, keyCompactionThreshold)
        cache.countLimit = max(1, countLimit)
    }

    func set(_ data: Data,
             for key: String,
             ttl: TimeInterval? = nil,
             source: DataSource = .network) {
        let effectiveTTL = ttl ?? self.ttl
        let metadata = Metadata(
            fetchedAt: Date(),
            ttl: effectiveTTL,
            source: source)
        cache.setObject(CacheEntry(data: data, metadata: metadata), forKey: key as NSString)
        knownKeys.insert(key)
        compactKnownKeysIfNeeded()
    }

    func value(for key: String) -> Data? {
        guard let cachedValue = cachedValue(for: key) else { return nil }
        return cachedValue.data
    }

    func cachedValue(for key: String, allowingStale: Bool = false) -> CachedValue? {
        guard let entry = cache.object(forKey: key as NSString) else { return nil }
        if entry.metadata.isStale, allowingStale == false {
            return nil
        }
        return CachedValue(data: entry.data, metadata: entry.metadata)
    }

    func metadata(for key: String) -> Metadata? {
        cache.object(forKey: key as NSString)?.metadata
    }

    func removeStaleEntries() {
        for key in Array(knownKeys) {
            guard let entry = cache.object(forKey: key as NSString) else {
                knownKeys.remove(key)
                continue
            }
            if entry.metadata.isStale {
                cache.removeObject(forKey: key as NSString)
                knownKeys.remove(key)
            }
        }
        compactKnownKeysIfNeeded(force: true)
    }

    func removeAll() {
        cache.removeAllObjects()
        knownKeys.removeAll()
    }

    private func compactKnownKeysIfNeeded(force: Bool = false) {
        guard force || knownKeys.count >= keyCompactionThreshold else { return }
        knownKeys = Set(knownKeys.filter { cache.object(forKey: $0 as NSString) != nil })
    }
}

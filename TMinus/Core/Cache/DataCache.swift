//
//  DataCache.swift
//  TMinus
//
//  Created by Sadegh on 22/04/2026.
//

import Foundation

actor DataCache {
    private final class CacheEntry {
        let data: Data
        let expiryDate: Date

        init(data: Data, expiryDate: Date) {
            self.data = data
            self.expiryDate = expiryDate
        }
    }

    private let cache = NSCache<NSString, CacheEntry>()
    private let ttl: TimeInterval

    init(ttl: TimeInterval = 300) {
        self.ttl = ttl
    }

    func set(_ data: Data, for key: String) {
        let expiryDate = Date().addingTimeInterval(ttl)
        cache.setObject(CacheEntry(data: data, expiryDate: expiryDate), forKey: key as NSString)
    }

    func value(for key: String) -> Data? {
        guard let entry = cache.object(forKey: key as NSString) else {
            return nil
        }

        guard entry.expiryDate > Date() else {
            cache.removeObject(forKey: key as NSString)
            return nil
        }

        return entry.data
    }

    func removeAll() {
        cache.removeAllObjects()
    }
}

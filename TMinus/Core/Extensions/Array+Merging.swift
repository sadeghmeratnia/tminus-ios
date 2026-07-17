//
//  Array+Merging.swift
//  TMinus
//
//  Created by Sadegh on 01/07/2026.
//

import Foundation

extension Array where Element: Identifiable {
    /// Appends items from `incoming` that aren't already present, and refreshes items that are
    /// — `incoming` is treated as the newer data, so an existing entry's fields (e.g. a launch's
    /// status, a news article's title) are replaced rather than kept stale.
    func merging(_ incoming: [Element]) -> [Element] {
        let incomingByID = Dictionary(incoming.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
        var seenIDs = Set(map(\.id))
        var merged = map { incomingByID[$0.id] ?? $0 }
        for item in incoming where !seenIDs.contains(item.id) {
            merged.append(item)
            seenIDs.insert(item.id)
        }
        return merged
    }
}

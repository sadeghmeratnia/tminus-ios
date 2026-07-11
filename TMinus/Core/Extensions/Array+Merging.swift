//
//  Array+Merging.swift
//  TMinus
//
//  Created by Sadegh on 01/07/2026.
//

import Foundation

extension Array where Element: Identifiable {
    func merging(_ incoming: [Element]) -> [Element] {
        var ids = Set(map(\.id))
        var merged = self
        for item in incoming where !ids.contains(item.id) {
            merged.append(item)
            ids.insert(item.id)
        }
        return merged
    }
}

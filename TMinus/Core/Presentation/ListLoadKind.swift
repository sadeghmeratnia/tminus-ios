//
//  ListLoadKind.swift
//  TMinus
//
//  Created by Sadegh on 01/07/2026.
//

import Foundation

// MARK: - ListLoadKind

/// Identifies the two kinds of load any paginated list screen can run concurrently, a fresh
/// load (initial/refresh/mode or search change) and a load-more (pagination), and encodes
/// which of the two each kind must cancel before starting. Shared so every list ViewModel gets
/// the same "a fresh load invalidates a pending load-more, but not vice versa" cancellation
/// behaviour for free instead of re-deriving it per feature.
enum ListLoadKind: Hashable {
    case fresh
    case loadMore

    var cancels: Set<ListLoadKind> {
        switch self {
        case .fresh:
            return [.fresh, .loadMore]
        case .loadMore:
            return [.loadMore]
        }
    }
}

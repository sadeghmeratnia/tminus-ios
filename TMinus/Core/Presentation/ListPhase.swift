//
//  ListPhase.swift
//  TMinus
//
//  Created by Sadegh on 01/07/2026.
//

import Foundation

// MARK: - ListPhase

/// The loading phase for any paginated list screen (e.g. `LaunchListState`, `NewsListState`).
/// Shared across features so every list screen models idle/loading/loaded/error identically —
/// new features should reuse this rather than defining a feature-specific phase enum.
enum ListPhase: Equatable {
    case idle
    case loading(LoadingKind)
    case loaded
    case error(message: String)

    // MARK: - LoadingKind

    enum LoadingKind: Equatable {
        case initial
        case refresh
        case loadMore
    }
}

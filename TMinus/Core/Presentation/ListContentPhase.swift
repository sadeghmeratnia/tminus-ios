//
//  ListContentPhase.swift
//  TMinus
//
//  Created by Sadegh on 11/07/2026.
//

import Foundation

// MARK: - ListContentPhase

/// A single, exhaustively-switchable view state for any paginated list screen, derived from
/// `ListPhase` combined with whether the list currently has items. The two inputs can't be
/// collapsed into `ListPhase` alone: `.loading(.loadMore)` should keep showing existing items
/// with a footer spinner rather than a full-screen loader, while `.loading(.initial)` is only
/// a full-screen loader while the list is still empty. Deriving one value up front lets the view
/// `switch` exhaustively instead of chaining `if`/`else if` conditions that the compiler can't
/// verify are complete.
enum ListContentPhase<Item> {
    case loading
    case error(message: String)
    case empty
    case content([Item])

    static func derive(phase: ListPhase, items: [Item]) -> ListContentPhase<Item> {
        guard items.isEmpty else {
            return .content(items)
        }

        switch phase {
        case .loading(.initial):
            return .loading
        case let .error(message):
            return .error(message: message)
        case .idle, .loaded, .loading(.refresh), .loading(.loadMore):
            return .empty
        }
    }
}

extension ListContentPhase: Equatable where Item: Equatable {}

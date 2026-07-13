//
//  ListContentPhase.swift
//  TMinus
//
//  Created by Sadegh on 11/07/2026.
//

import Foundation

// MARK: - ListContentPhase

/// Exhaustively-switchable view state for any list screen, derived from `ListPhase` and whether
/// the list has items.
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

    /// Non-nil only when a refresh failed but stale items are still on screen — mirrors how
    /// `ListPagination.loadMoreError` sits beside `ListPhase` rather than inside it, so a
    /// transient advisory never needs to be smuggled into a case that's meant to mean one thing.
    static func refreshErrorMessage(phase: ListPhase, items: [Item]) -> String? {
        guard items.isEmpty == false, case let .error(message) = phase else { return nil }
        return message
    }
}

extension ListContentPhase: Equatable where Item: Equatable {}

//
//  ListPagination.swift
//  TMinus
//
//  Created by Sadegh on 01/07/2026.
//

import Foundation

// MARK: - FieldUpdate

/// Distinguishes "leave this field as it is" from "set it to this value, including `nil`" for an
/// optional field, a plain `T? = nil` default on `with(...)`-style methods can't tell those two
/// intents apart, since "no update" and "explicitly clear" would both be spelled `nil`.
enum FieldUpdate<Value> {
    case unchanged
    case set(Value)

    fileprivate func applying(to current: Value) -> Value {
        switch self {
        case .unchanged: current
        case let .set(value): value
        }
    }
}

// MARK: - ListPagination

/// Pagination state for any list screen, current/next/previous page, total count, and any
/// load-more error. Generic over the item type via `applying(page:)`, so it plugs into any
/// `PagedResult<Item>` without a feature needing its own pagination type.
struct ListPagination: Equatable, Sendable {
    let currentPage: Int
    let nextPage: Int?
    let previousPage: Int?
    let totalCount: Int?
    let loadMoreError: String?

    static let initial = ListPagination(
        currentPage: 1,
        nextPage: nil,
        previousPage: nil,
        totalCount: nil,
        loadMoreError: nil
    )

    /// `nextPage`/`previousPage`/`totalCount`/`loadMoreError` take a `FieldUpdate`: omit the
    /// argument (defaults to `.unchanged`) to leave the field as-is, or pass `.set(nil)` to
    /// explicitly clear it, a plain `Int? = nil` default can't distinguish "no update" from
    /// "set this back to nil".
    func with(currentPage: Int? = nil,
              nextPage: FieldUpdate<Int?> = .unchanged,
              previousPage: FieldUpdate<Int?> = .unchanged,
              totalCount: FieldUpdate<Int?> = .unchanged,
              loadMoreError: FieldUpdate<String?> = .unchanged) -> ListPagination
    {
        ListPagination(
            currentPage: currentPage ?? self.currentPage,
            nextPage: nextPage.applying(to: self.nextPage),
            previousPage: previousPage.applying(to: self.previousPage),
            totalCount: totalCount.applying(to: self.totalCount),
            loadMoreError: loadMoreError.applying(to: self.loadMoreError)
        )
    }

    func applying(page: PagedResult<some Sendable>) -> ListPagination {
        with(
            currentPage: page.currentPage,
            nextPage: .set(page.nextPage),
            previousPage: .set(page.previousPage),
            totalCount: .set(page.totalCount),
            loadMoreError: .set(nil)
        )
    }

    func failingLoadMore(message: String) -> ListPagination {
        with(loadMoreError: .set(message))
    }

    func clearingLoadMoreError() -> ListPagination {
        with(loadMoreError: .set(nil))
    }

    /// The page to retry with, if there's a failed load-more to retry, `nil` when there's no
    /// load-more error, or no next page to load. Shared so every list reducer's `.retryLoadMore`
    /// guard reads this the same way instead of re-deriving it per feature.
    var retryLoadMorePage: Int? {
        guard loadMoreError != nil else { return nil }
        return nextPage
    }
}

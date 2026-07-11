//
//  ListPagination.swift
//  TMinus
//
//  Created by Sadegh on 01/07/2026.
//

import Foundation

// MARK: - ListPagination

/// Pagination state for any list screen, current/next/previous page, total count, and any
/// load-more error. Generic over the item type via `applying(page:)`, so it plugs into any
/// `PagedResult<Item>` without a feature needing its own pagination type.
struct ListPagination: Equatable {
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
        loadMoreError: nil)

    func with(currentPage: Int? = nil,
              nextPage: Int? = nil,
              previousPage: Int? = nil,
              totalCount: Int? = nil,
              loadMoreError: String? = nil,
              clearsLoadMoreError: Bool = false) -> ListPagination {
        ListPagination(
            currentPage: currentPage ?? self.currentPage,
            nextPage: nextPage ?? self.nextPage,
            previousPage: previousPage ?? self.previousPage,
            totalCount: totalCount ?? self.totalCount,
            loadMoreError: clearsLoadMoreError ? nil : (loadMoreError ?? self.loadMoreError))
    }

    func applying(page: PagedResult<some Sendable>) -> ListPagination {
        self.with(
            currentPage: page.currentPage,
            nextPage: page.nextPage,
            previousPage: page.previousPage,
            totalCount: page.totalCount,
            loadMoreError: nil,
            clearsLoadMoreError: true)
    }

    func failingLoadMore(message: String) -> ListPagination {
        self.with(loadMoreError: message)
    }

    func clearingLoadMoreError() -> ListPagination {
        self.with(loadMoreError: nil, clearsLoadMoreError: true)
    }
}

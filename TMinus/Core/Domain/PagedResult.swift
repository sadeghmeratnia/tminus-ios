//
//  PagedResult.swift
//  TMinus
//
//  Created by Sadegh on 22/05/2026.
//

import Foundation

// MARK: - PagedResult

/// A page of results and its pagination metadata, shared by Launches and News.
struct PagedResult<Item: Sendable>: Sendable {
    let items: [Item]
    let currentPage: Int
    let totalCount: Int?
    let nextPage: Int?
    let previousPage: Int?

    init(items: [Item],
         currentPage: Int = 1,
         totalCount: Int? = nil,
         nextPage: Int? = nil,
         previousPage: Int? = nil)
    {
        self.items = items
        self.currentPage = currentPage
        self.totalCount = totalCount
        self.nextPage = nextPage
        self.previousPage = previousPage
    }
}

extension PagedResult: Equatable where Item: Equatable {}

extension PagedResult {
    /// Builds pagination for cached rows, which do not include the server's pagination metadata.
    /// A non-empty cache result stays optimistic about the next page; the network confirms it on
    /// the next load. This avoids hiding later pages when mapping drops an invalid row.
    static func fromCachePage(items: [Item], page: Int) -> PagedResult<Item> {
        PagedResult(
            items: items,
            currentPage: page,
            nextPage: items.isEmpty ? nil : page + 1,
            previousPage: page > 1 ? page - 1 : nil
        )
    }
}

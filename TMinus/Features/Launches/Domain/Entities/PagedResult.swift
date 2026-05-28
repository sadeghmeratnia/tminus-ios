//
//  PagedResult.swift
//  TMinus
//
//  Created by Sadegh on 22/05/2026.
//

import Foundation

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
         previousPage: Int? = nil) {
        self.items = items
        self.currentPage = currentPage
        self.totalCount = totalCount
        self.nextPage = nextPage
        self.previousPage = previousPage
    }
}

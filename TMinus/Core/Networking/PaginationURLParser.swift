//
//  PaginationURLParser.swift
//  TMinus
//
//  Created by Sadegh on 01/07/2026.
//

import Foundation

// MARK: - PaginationURLParser

enum PaginationURLParser {
    static func pageNumber(from urlString: String?, fallbackLimit: Int) -> Int? {
        guard let urlString,
              let components = URLComponents(string: urlString),
              let queryItems = components.queryItems
        else { return nil }

        let safeLimit = max(1, fallbackLimit)
        let offset = queryItems.first(where: { $0.name == "offset" })
            .flatMap { Int($0.value ?? "") } ?? 0
        let limit = queryItems.first(where: { $0.name == "limit" })
            .flatMap { Int($0.value ?? "") }
            .flatMap { $0 > 0 ? $0 : nil } ?? safeLimit
        return (offset / limit) + 1
    }
}

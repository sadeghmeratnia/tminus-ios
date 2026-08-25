//
//  PaginationQueryItemBuilder.swift
//  TMinus
//

import Foundation

// MARK: - PaginationQueryItemBuilder

/// Builds the `limit`/`offset`/`search` query items shared by every paginated list endpoint in
/// this app (`LaunchesEndpoint`, `NewsEndpoint`), previously each endpoint hand-rolled the same
/// page-to-offset math independently, which meant a fix or change to it had to be made (and kept
/// in sync) in two places. Feature-specific items (e.g. `ordering`) stay the caller's
/// responsibility; this only owns the part every endpoint shares.
enum PaginationQueryItemBuilder {
    /// Clamps `page`/`limit` to sane positive values first, so a caller-supplied `0` or negative
    /// value can't produce a negative `offset`.
    static func makeItems(page: Int, limit: Int, searchText: String?) -> [URLQueryItem] {
        let safePage = max(1, page)
        let safeLimit = max(1, limit)
        let offset = (safePage - 1) * safeLimit

        var items = [
            URLQueryItem(name: "limit", value: String(safeLimit)),
            URLQueryItem(name: "offset", value: String(offset)),
        ]

        if let searchText, searchText.isEmpty == false {
            items.append(URLQueryItem(name: "search", value: searchText))
        }

        return items
    }
}

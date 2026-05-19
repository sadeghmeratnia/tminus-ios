//
//  LaunchesEndpoint.swift
//  TMinus
//
//  Created by Sadegh on 06/05/2026.
//

import Foundation

enum LaunchesEndpoint {
    private enum CacheTTL {
        static let upcoming: TimeInterval = 120
        static let previous: TimeInterval = 900
        static let detail: TimeInterval = 1800
    }

    static func upcoming(query: LaunchListQuery) -> Endpoint {
        Endpoint(
            path: "launches/upcoming/",
            queryItems: makeQueryItems(query: query, ordering: "window_start"),
            cacheTTL: CacheTTL.upcoming)
    }

    static func previous(query: LaunchListQuery) -> Endpoint {
        Endpoint(
            path: "launches/previous/",
            queryItems: makeQueryItems(query: query, ordering: "-window_start"),
            cacheTTL: CacheTTL.previous)
    }

    static func detail(id: String) -> Endpoint {
        Endpoint(path: "launches/\(id)/", cacheTTL: CacheTTL.detail)
    }

    private static func makeQueryItems(query: LaunchListQuery, ordering: String) -> [URLQueryItem] {
        let safePage = max(1, query.page)
        let safeLimit = max(1, query.limit)
        let offset = (safePage - 1) * safeLimit

        var items = [
            URLQueryItem(name: "limit", value: String(safeLimit)),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "ordering", value: ordering),
        ]

        if let search = query.searchText, search.isEmpty == false {
            items.append(URLQueryItem(name: "search", value: search))
        }

        return items
    }
}

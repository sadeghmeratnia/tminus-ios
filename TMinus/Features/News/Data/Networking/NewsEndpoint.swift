//
//  NewsEndpoint.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import Foundation

enum NewsEndpoint {
    static let baseURL = APIEnvironment.current.spaceflightNewsBaseURL

    static func list(query: NewsListQuery) -> Endpoint {
        Endpoint(
            baseURL: baseURL,
            path: "articles/",
            queryItems: makeQueryItems(query: query),
            cacheTTL: NewsCacheTTL.list
        )
    }

    static func detail(id: String) -> Endpoint {
        Endpoint(baseURL: baseURL, path: "articles/\(id)/", cacheTTL: NewsCacheTTL.detail)
    }

    static func related(launchID: String, limit: Int) -> Endpoint {
        Endpoint(
            baseURL: baseURL,
            path: "articles/",
            queryItems: [
                URLQueryItem(name: "limit", value: String(max(1, limit))),
                URLQueryItem(name: "launch", value: launchID),
            ],
            cacheTTL: NewsCacheTTL.related
        )
    }

    private static func makeQueryItems(query: NewsListQuery) -> [URLQueryItem] {
        let safePage = max(1, query.page)
        let safeLimit = max(1, query.limit)
        let offset = (safePage - 1) * safeLimit

        var items = [
            URLQueryItem(name: "limit", value: String(safeLimit)),
            URLQueryItem(name: "offset", value: String(offset)),
        ]

        if let search = query.searchText, search.isEmpty == false {
            items.append(URLQueryItem(name: "search", value: search))
        }

        return items
    }
}

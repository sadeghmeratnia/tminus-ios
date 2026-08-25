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
        Endpoint(baseURL: baseURL, path: "articles/\(id.urlPathComponentEncoded)/", cacheTTL: NewsCacheTTL.detail)
    }

    static func related(launchID: String, limit: Int) -> Endpoint {
        Endpoint(
            baseURL: baseURL,
            path: "articles/",
            queryItems: [
                URLQueryItem(name: "limit", value: String(max(1, limit))),
                URLQueryItem(name: "launch", value: launchID),
                // Pinned explicitly rather than left to the API's default, matching every
                // `LaunchesEndpoint` list query, `SwiftDataNewsLocalDataSource.fetchRelatedArticles`
                // sorts its own cached results by `publishedAt` descending, so the remote and
                // cached paths would silently disagree on ordering if the API's default ever
                // isn't newest-first.
                URLQueryItem(name: "ordering", value: "-published_at"),
            ],
            cacheTTL: NewsCacheTTL.related
        )
    }

    private static func makeQueryItems(query: NewsListQuery) -> [URLQueryItem] {
        PaginationQueryItemBuilder.makeItems(page: query.page, limit: query.limit, searchText: query.searchText)
    }
}

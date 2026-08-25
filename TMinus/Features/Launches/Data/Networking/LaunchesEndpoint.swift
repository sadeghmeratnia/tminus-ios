//
//  LaunchesEndpoint.swift
//  TMinus
//
//  Created by Sadegh on 06/05/2026.
//

import Foundation

enum LaunchesEndpoint {
    static let baseURL = APIEnvironment.current.launchLibraryBaseURL

    static func upcoming(query: LaunchListQuery) -> Endpoint {
        Endpoint(
            baseURL: baseURL,
            path: "launches/upcoming/",
            queryItems: makeQueryItems(query: query, ordering: "window_start"),
            cacheTTL: LaunchCacheTTL.upcoming
        )
    }

    static func previous(query: LaunchListQuery) -> Endpoint {
        Endpoint(
            baseURL: baseURL,
            path: "launches/previous/",
            queryItems: makeQueryItems(query: query, ordering: "-window_start"),
            cacheTTL: LaunchCacheTTL.previous
        )
    }

    static func detail(id: String) -> Endpoint {
        Endpoint(baseURL: baseURL, path: "launches/\(id.urlPathComponentEncoded)/", cacheTTL: LaunchCacheTTL.detail)
    }

    private static func makeQueryItems(query: LaunchListQuery, ordering: String) -> [URLQueryItem] {
        PaginationQueryItemBuilder.makeItems(page: query.page, limit: query.limit, searchText: query.searchText)
            + [URLQueryItem(name: "ordering", value: ordering)]
    }
}

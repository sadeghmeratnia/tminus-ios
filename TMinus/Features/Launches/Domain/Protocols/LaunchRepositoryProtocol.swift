//
//  LaunchRepositoryProtocol.swift
//  TMinus
//
//  Created by Sadegh on 06/05/2026.
//

import Foundation

// MARK: - LaunchRepositoryProtocol

protocol LaunchRepositoryProtocol: Sendable {
    func fetchUpcomingLaunches(query: LaunchListQuery) async throws -> PagedResult<Launch>
    func fetchPreviousLaunches(query: LaunchListQuery) async throws -> PagedResult<Launch>
    func fetchLaunchDetail(id: String) async throws -> Launch
}

// MARK: - LaunchListQuery

struct LaunchListQuery: Equatable {
    let page: Int
    let limit: Int
    let searchText: String?
    let fetchPolicy: FetchPolicy

    init(page: Int = 1,
         limit: Int = 20,
         searchText: String? = nil,
         fetchPolicy: FetchPolicy = .useCache)
    {
        self.page = page
        self.limit = limit
        self.searchText = searchText?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.fetchPolicy = fetchPolicy
    }
}

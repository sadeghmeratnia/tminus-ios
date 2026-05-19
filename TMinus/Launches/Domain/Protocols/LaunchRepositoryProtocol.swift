//
//  LaunchRepositoryProtocol.swift
//  TMinus
//
//  Created by Sadegh on 06/05/2026.
//

import Foundation

enum LaunchFetchPolicy: Equatable, Sendable {
    case useCache
    case networkOnly
}

// MARK: - LaunchRepositoryProtocol

protocol LaunchRepositoryProtocol {
    func fetchUpcomingLaunches(query: LaunchListQuery) async throws -> [Launch]
    func fetchPreviousLaunches(query: LaunchListQuery) async throws -> [Launch]
    func fetchLaunchDetail(id: String) async throws -> Launch
}

// MARK: - LaunchListQuery

struct LaunchListQuery: Equatable, Sendable {
    let page: Int
    let limit: Int
    let searchText: String?
    let fetchPolicy: LaunchFetchPolicy

    init(page: Int = 1,
         limit: Int = 20,
         searchText: String? = nil,
         fetchPolicy: LaunchFetchPolicy = .useCache) {
        self.page = page
        self.limit = limit
        self.searchText = searchText?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.fetchPolicy = fetchPolicy
    }
}

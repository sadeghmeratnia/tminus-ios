//
//  LaunchRepositoryProtocol.swift
//  TMinus
//
//  Created by Sadegh on 06/05/2026.
//

import Foundation

// MARK: - LaunchRepositoryProtocol

protocol LaunchRepositoryProtocol {
    func fetchUpcomingLaunches(query: LaunchListQuery) async throws -> [Launch]
    func fetchPreviousLaunches(query: LaunchListQuery) async throws -> [Launch]
    func fetchLaunchDetail(id: String) async throws -> Launch
}

// MARK: - LaunchListQuery

struct LaunchListQuery: Equatable {
    let page: Int
    let limit: Int
    let searchText: String?

    init(page: Int = 1,
         limit: Int = 20,
         searchText: String? = nil) {
        self.page = page
        self.limit = limit
        self.searchText = searchText?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

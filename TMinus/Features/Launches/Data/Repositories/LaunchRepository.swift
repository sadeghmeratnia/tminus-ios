//
//  LaunchRepository.swift
//  TMinus
//
//  Created by Sadegh on 06/05/2026.
//

import Foundation

// MARK: - LaunchRepository

final class LaunchRepository: LaunchRepositoryProtocol {
    private let remoteDataSource: LaunchRemoteDataSource
    private let localDataSource: LaunchLocalDataSource

    init(remoteDataSource: LaunchRemoteDataSource,
         localDataSource: LaunchLocalDataSource) {
        self.remoteDataSource = remoteDataSource
        self.localDataSource = localDataSource
    }

    func fetchUpcomingLaunches(query: LaunchListQuery) async throws -> PagedResult<Launch> {
        try await fetchWithLocalFallback(
            query: query,
            maxAge: LaunchCacheTTL.upcoming,
            local: { try await self.localDataSource.fetchUpcomingLaunches(query: $0, maxAge: $1) },
            remote: {
                let response = try await self.remoteDataSource.fetchUpcomingLaunches(query: query)
                return Self.mapPage(response, query: query)
            })
    }

    func fetchPreviousLaunches(query: LaunchListQuery) async throws -> PagedResult<Launch> {
        try await fetchWithLocalFallback(
            query: query,
            maxAge: LaunchCacheTTL.previous,
            local: { try await self.localDataSource.fetchPreviousLaunches(query: $0, maxAge: $1) },
            remote: {
                let response = try await self.remoteDataSource.fetchPreviousLaunches(query: query)
                return Self.mapPage(response, query: query)
            })
    }

    func fetchLaunchDetail(id: String) async throws -> Launch {
        if let cached = try await localDataSource.fetchLaunchDetail(id: id, maxAge: LaunchCacheTTL.detail) {
            return cached
        }

        do {
            let dto = try await remoteDataSource.fetchLaunchDetail(id: id, fetchPolicy: .useCache)
            let launch = LaunchDTOMapper.map(dto)
            try await localDataSource.save(launch, fetchedAt: Date())
            return launch
        } catch {
            if let stale = try await localDataSource.fetchLaunchDetail(id: id, maxAge: nil) {
                return stale
            }
            throw LaunchErrorMapper.map(error)
        }
    }
}

extension LaunchRepository {
    private func fetchWithLocalFallback(query: LaunchListQuery,
                                        maxAge: TimeInterval,
                                        local: (LaunchListQuery, TimeInterval?) async throws -> [Launch],
                                        remote: () async throws -> PagedResult<Launch>) async throws
        -> PagedResult<Launch> {
        if query.fetchPolicy == .useCache {
            let cached = try await local(query, maxAge)
            if !cached.isEmpty {
                return PagedResult(
                    items: cached,
                    currentPage: query.page,
                    previousPage: query.page > 1 ? query.page - 1 : nil)
            }
        }

        do {
            let page = try await remote()
            try await localDataSource.save(page.items, fetchedAt: Date())
            return page
        } catch {
            if query.fetchPolicy == .useCache {
                let stale = try await local(query, nil)
                if !stale.isEmpty {
                    return PagedResult(
                        items: stale,
                        currentPage: query.page,
                        previousPage: query.page > 1 ? query.page - 1 : nil)
                }
            }
            throw LaunchErrorMapper.map(error)
        }
    }

    fileprivate static func mapPage(_ response: LaunchesResponseDTO, query: LaunchListQuery) -> PagedResult<Launch> {
        PagedResult(
            items: response.results.map(LaunchDTOMapper.map(_:)),
            currentPage: query.page,
            totalCount: response.count,
            nextPage: PaginationURLParser.pageNumber(from: response.next, fallbackLimit: query.limit),
            previousPage: PaginationURLParser.pageNumber(from: response.previous, fallbackLimit: query.limit))
    }
}

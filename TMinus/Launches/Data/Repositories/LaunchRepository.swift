//
//  LaunchRepository.swift
//  TMinus
//
//  Created by Sadegh on 06/05/2026.
//

import Foundation

final class LaunchRepository: LaunchRepositoryProtocol {
    private let remoteDataSource: LaunchRemoteDataSource
    private let localDataSource: LaunchLocalDataSource

    init(remoteDataSource: LaunchRemoteDataSource,
         localDataSource: LaunchLocalDataSource) {
        self.remoteDataSource = remoteDataSource
        self.localDataSource = localDataSource
    }

    func fetchUpcomingLaunches(query: LaunchListQuery) async throws -> [Launch] {
        try await fetchWithLocalFallback(
            query: query,
            maxAge: LaunchCacheTTL.upcoming,
            local: { try await self.localDataSource.fetchUpcomingLaunches(query: $0, maxAge: $1) },
            remote: {
                let response = try await self.remoteDataSource.fetchUpcomingLaunches(query: query)
                return response.results.map(LaunchDTOMapper.map(_:))
            })
    }

    func fetchPreviousLaunches(query: LaunchListQuery) async throws -> [Launch] {
        try await fetchWithLocalFallback(
            query: query,
            maxAge: LaunchCacheTTL.previous,
            local: { try await self.localDataSource.fetchPreviousLaunches(query: $0, maxAge: $1) },
            remote: {
                let response = try await self.remoteDataSource.fetchPreviousLaunches(query: query)
                return response.results.map(LaunchDTOMapper.map(_:))
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

private extension LaunchRepository {
    func fetchWithLocalFallback(
        query: LaunchListQuery,
        maxAge: TimeInterval,
        local: (LaunchListQuery, TimeInterval?) async throws -> [Launch],
        remote: () async throws -> [Launch]
    ) async throws -> [Launch] {
        if query.fetchPolicy == .useCache {
            let cached = try await local(query, maxAge)
            if !cached.isEmpty { return cached }
        }

        do {
            let launches = try await remote()
            try await localDataSource.save(launches, fetchedAt: Date())
            return launches
        } catch {
            if query.fetchPolicy == .useCache {
                let stale = try await local(query, nil)
                if !stale.isEmpty { return stale }
            }
            throw LaunchErrorMapper.map(error)
        }
    }
}

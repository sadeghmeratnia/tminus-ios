//
//  LaunchRepository.swift
//  TMinus
//
//  Created by Sadegh on 06/05/2026.
//

import Foundation

final class LaunchRepository: LaunchRepositoryProtocol {
    private let remoteDataSource: LaunchRemoteDataSource
    private let localDataSource: LaunchLocalDataSource?

    init(remoteDataSource: LaunchRemoteDataSource,
         localDataSource: LaunchLocalDataSource? = nil) {
        self.remoteDataSource = remoteDataSource
        self.localDataSource = localDataSource
    }

    func fetchUpcomingLaunches(query: LaunchListQuery) async throws -> [Launch] {
        let endpoint = LaunchesEndpoint.upcoming(query: query)

        if query.fetchPolicy == .useCache,
           let cached = try await localDataSource?.fetchUpcomingLaunches(query: query, maxAge: endpoint.cacheTTL),
           cached.isEmpty == false {
            return cached
        }

        do {
            let response = try await remoteDataSource.fetchUpcomingLaunches(query: query)
            let launches = response.results.map(LaunchDTOMapper.map(_:))
            try await localDataSource?.save(launches, fetchedAt: Date())
            return launches
        } catch {
            if query.fetchPolicy == .useCache,
               let stale = try await localDataSource?.fetchUpcomingLaunches(query: query, maxAge: nil),
               stale.isEmpty == false {
                return stale
            }
            throw error
        }
    }

    func fetchPreviousLaunches(query: LaunchListQuery) async throws -> [Launch] {
        let endpoint = LaunchesEndpoint.previous(query: query)

        if query.fetchPolicy == .useCache,
           let cached = try await localDataSource?.fetchPreviousLaunches(query: query, maxAge: endpoint.cacheTTL),
           cached.isEmpty == false {
            return cached
        }

        do {
            let response = try await remoteDataSource.fetchPreviousLaunches(query: query)
            let launches = response.results.map(LaunchDTOMapper.map(_:))
            try await localDataSource?.save(launches, fetchedAt: Date())
            return launches
        } catch {
            if query.fetchPolicy == .useCache,
               let stale = try await localDataSource?.fetchPreviousLaunches(query: query, maxAge: nil),
               stale.isEmpty == false {
                return stale
            }
            throw error
        }
    }

    func fetchLaunchDetail(id: String) async throws -> Launch {
        let endpoint = LaunchesEndpoint.detail(id: id)

        if let cached = try await localDataSource?.fetchLaunchDetail(id: id, maxAge: endpoint.cacheTTL) {
            return cached
        }

        do {
            let dto = try await remoteDataSource.fetchLaunchDetail(id: id, fetchPolicy: .useCache)
            let launch = LaunchDTOMapper.map(dto)
            try await localDataSource?.save(launch, fetchedAt: Date())
            return launch
        } catch {
            if let stale = try await localDataSource?.fetchLaunchDetail(id: id, maxAge: nil) {
                return stale
            }
            throw error
        }
    }
}

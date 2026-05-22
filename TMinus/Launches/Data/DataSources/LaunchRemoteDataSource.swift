//
//  LaunchRemoteDataSource.swift
//  TMinus
//
//  Created by Sadegh on 19/05/2026.
//

import Foundation

protocol LaunchRemoteDataSource {
    func fetchUpcomingLaunches(query: LaunchListQuery) async throws -> LaunchesResponseDTO
    func fetchPreviousLaunches(query: LaunchListQuery) async throws -> LaunchesResponseDTO
    func fetchLaunchDetail(id: String, fetchPolicy: LaunchFetchPolicy) async throws -> LaunchDTO
}

final class NetworkLaunchRemoteDataSource: LaunchRemoteDataSource {
    private let networkClient: NetworkClientProtocol

    init(networkClient: NetworkClientProtocol) {
        self.networkClient = networkClient
    }

    func fetchUpcomingLaunches(query: LaunchListQuery) async throws -> LaunchesResponseDTO {
        try await networkClient.request(
            LaunchesResponseDTO.self,
            endpoint: LaunchesEndpoint.upcoming(query: query),
            cachePolicy: query.fetchPolicy.networkCachePolicy)
    }

    func fetchPreviousLaunches(query: LaunchListQuery) async throws -> LaunchesResponseDTO {
        try await networkClient.request(
            LaunchesResponseDTO.self,
            endpoint: LaunchesEndpoint.previous(query: query),
            cachePolicy: query.fetchPolicy.networkCachePolicy)
    }

    func fetchLaunchDetail(id: String, fetchPolicy: LaunchFetchPolicy) async throws -> LaunchDTO {
        try await networkClient.request(
            LaunchDTO.self,
            endpoint: LaunchesEndpoint.detail(id: id),
            cachePolicy: fetchPolicy.networkCachePolicy)
    }
}

private extension LaunchFetchPolicy {
    var networkCachePolicy: CachePolicy {
        switch self {
        case .useCache:
            return .useCache
        case .networkOnly:
            return .networkOnly
        }
    }
}

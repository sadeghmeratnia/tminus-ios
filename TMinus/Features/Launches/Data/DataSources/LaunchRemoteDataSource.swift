//
//  LaunchRemoteDataSource.swift
//  TMinus
//
//  Created by Sadegh on 19/05/2026.
//

import Foundation

// MARK: - LaunchRemoteDataSource

protocol LaunchRemoteDataSource: Sendable {
    func fetchUpcomingLaunches(query: LaunchListQuery) async throws -> LaunchesResponseDTO
    func fetchPreviousLaunches(query: LaunchListQuery) async throws -> LaunchesResponseDTO
    func fetchLaunchDetail(id: String, fetchPolicy: FetchPolicy) async throws -> LaunchDTO
}

// MARK: - NetworkLaunchRemoteDataSource

final class NetworkLaunchRemoteDataSource: LaunchRemoteDataSource, Sendable {
    private let networkClient: NetworkClientProtocol

    init(networkClient: NetworkClientProtocol) {
        self.networkClient = networkClient
    }

    func fetchUpcomingLaunches(query: LaunchListQuery) async throws -> LaunchesResponseDTO {
        try await networkClient.request(
            LaunchesResponseDTO.self,
            endpoint: LaunchesEndpoint.upcoming(query: query),
            cachePolicy: query.fetchPolicy)
    }

    func fetchPreviousLaunches(query: LaunchListQuery) async throws -> LaunchesResponseDTO {
        try await networkClient.request(
            LaunchesResponseDTO.self,
            endpoint: LaunchesEndpoint.previous(query: query),
            cachePolicy: query.fetchPolicy)
    }

    func fetchLaunchDetail(id: String, fetchPolicy: FetchPolicy) async throws -> LaunchDTO {
        try await networkClient.request(
            LaunchDTO.self,
            endpoint: LaunchesEndpoint.detail(id: id),
            cachePolicy: fetchPolicy)
    }
}

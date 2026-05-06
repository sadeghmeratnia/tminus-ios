//
//  LaunchRepository.swift
//  TMinus
//
//  Created by Sadegh on 06/05/2026.
//

import Foundation

final class LaunchRepository: LaunchRepositoryProtocol {
    private let networkClient: NetworkClientProtocol

    init(networkClient: NetworkClientProtocol) {
        self.networkClient = networkClient
    }

    func fetchUpcomingLaunches(query: LaunchListQuery) async throws -> [Launch] {
        let response = try await networkClient.request(
            LaunchesResponseDTO.self,
            endpoint: LaunchesEndpoint.upcoming(query: query))
        return response.results.map(LaunchDTOMapper.map(_:))
    }

    func fetchPreviousLaunches(query: LaunchListQuery) async throws -> [Launch] {
        let response = try await networkClient.request(
            LaunchesResponseDTO.self,
            endpoint: LaunchesEndpoint.previous(query: query))
        return response.results.map(LaunchDTOMapper.map(_:))
    }

    func fetchLaunchDetail(id: String) async throws -> Launch {
        let dto = try await networkClient.request(
            LaunchDTO.self,
            endpoint: LaunchesEndpoint.detail(id: id))
        return LaunchDTOMapper.map(dto)
    }
}

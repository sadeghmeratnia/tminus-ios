//
//  FetchUpcomingLaunchesUseCase.swift
//  TMinus
//
//  Created by Sadegh on 06/05/2026.
//

import Foundation

struct FetchUpcomingLaunchesUseCase {
    private let repository: LaunchRepositoryProtocol

    init(repository: LaunchRepositoryProtocol) {
        self.repository = repository
    }

    func execute(query: LaunchListQuery) async throws -> [Launch] {
        try await repository.fetchUpcomingLaunches(query: query)
    }
}

//
//  UseCaseFactory.swift
//  TMinus
//
//  Created by Sadegh on 23/04/2026.
//

import Foundation

final class UseCaseFactory {
    private let repositoryFactory: RepositoryFactory
    lazy var fetchUpcomingLaunchesUseCase = FetchUpcomingLaunchesUseCase(repository: repositoryFactory.launchRepository)
    lazy var fetchPreviousLaunchesUseCase = FetchPreviousLaunchesUseCase(repository: repositoryFactory.launchRepository)
    lazy var fetchLaunchDetailUseCase = FetchLaunchDetailUseCase(repository: repositoryFactory.launchRepository)

    init(repositoryFactory: RepositoryFactory) {
        self.repositoryFactory = repositoryFactory
    }
}

//
//  DIContainer.swift
//  TMinus
//
//  Created by Sadegh on 22/04/2026.
//

import Foundation

// MARK: - DIContainer

final class DIContainer {
    private let networkingFactory: NetworkingFactory
    private let repositoryFactory: RepositoryFactory
    private let useCaseFactory: UseCaseFactory
    let coordinatorFactory: CoordinatorFactory

    init(apiEnvironment: APIEnvironment = .current) {
        let networking = NetworkingFactory(apiEnvironment: apiEnvironment)
        let repositories = RepositoryFactory(networkingFactory: networking)
        let useCases = UseCaseFactory(repositoryFactory: repositories)

        self.networkingFactory = networking
        self.repositoryFactory = repositories
        self.useCaseFactory = useCases
        self.coordinatorFactory = CoordinatorFactory(useCaseFactory: useCases)
    }
}

//
//  LaunchesFeatureBuilder.swift
//  TMinus
//
//  Created by Sadegh on 22/05/2026.
//

import Foundation
import SwiftData

// MARK: - LaunchesFeatureBuilder

final class LaunchesFeatureBuilder {
    struct Dependencies {
        let networkClient: NetworkClientProtocol
        let modelContainer: ModelContainer
    }

    private let dependencies: Dependencies

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    @MainActor
    func makeCoordinator() -> LaunchesCoordinator {
        let repository = makeRepository()
        let viewModel = LaunchListViewModel(
            fetchUpcomingLaunchesUseCase: FetchUpcomingLaunchesUseCase(repository: repository),
            fetchPreviousLaunchesUseCase: FetchPreviousLaunchesUseCase(repository: repository))
        return LaunchesCoordinator(viewModel: viewModel)
    }

    private func makeRepository() -> LaunchRepositoryProtocol {
        let remote = NetworkLaunchRemoteDataSource(networkClient: dependencies.networkClient)
        let local = SwiftDataLaunchLocalDataSource(container: dependencies.modelContainer)
        return LaunchRepository(remoteDataSource: remote, localDataSource: local)
    }
}

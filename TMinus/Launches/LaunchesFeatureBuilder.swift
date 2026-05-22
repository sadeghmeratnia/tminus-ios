//
//  LaunchesFeatureBuilder.swift
//  TMinus
//
//  Created by Sadegh on 22/05/2026.
//

import Foundation

final class LaunchesFeatureBuilder {
    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
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
        let remote = NetworkLaunchRemoteDataSource(networkClient: container.networkClient)
        let local = SwiftDataLaunchLocalDataSource(container: container.modelContainer)
        return LaunchRepository(remoteDataSource: remote, localDataSource: local)
    }
}

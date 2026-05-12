//
//  CoordinatorFactory.swift
//  TMinus
//
//  Created by Sadegh on 23/04/2026.
//

import Foundation

final class CoordinatorFactory {
    private let useCaseFactory: UseCaseFactory

    init(useCaseFactory: UseCaseFactory) {
        self.useCaseFactory = useCaseFactory
    }

    @MainActor
    func makeAppCoordinator() -> AppCoordinator {
        AppCoordinator(launchesCoordinator: makeLaunchesCoordinator())
    }

    @MainActor
    func makeLaunchesCoordinator() -> LaunchesCoordinator {
        let viewModel = LaunchListViewModel(
            fetchUpcomingLaunchesUseCase: useCaseFactory.fetchUpcomingLaunchesUseCase,
            fetchPreviousLaunchesUseCase: useCaseFactory.fetchPreviousLaunchesUseCase)
        return LaunchesCoordinator(viewModel: viewModel)
    }
}

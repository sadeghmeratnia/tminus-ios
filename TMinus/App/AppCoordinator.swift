//
//  AppCoordinator.swift
//  TMinus
//
//  Created by Sadegh on 07/05/2026.
//

import SwiftUI

@MainActor
final class AppCoordinator: CoordinatorProtocol {
    typealias RootView = LaunchesRootView

    private let container: AppContainer
    private lazy var launchesCoordinator: LaunchesCoordinator = LaunchesFeatureBuilder(
        dependencies: LaunchesFeatureBuilder.Dependencies(
            networkClient: container.networkClient,
            modelContainer: container.modelContainer))
        .makeCoordinator()

    init(container: AppContainer) {
        self.container = container
    }

    func makeRootView() -> LaunchesRootView {
        launchesCoordinator.makeRootView()
    }
}

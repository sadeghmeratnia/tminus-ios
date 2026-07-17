//
//  AppCoordinator.swift
//  TMinus
//
//  Created by Sadegh on 07/05/2026.
//

import SwiftUI

@MainActor
final class AppCoordinator: CoordinatorProtocol {
    typealias RootView = AppRootView

    private let container: AppContainer
    private lazy var newsFeatureBuilder = NewsFeatureBuilder(
        dependencies: NewsFeatureBuilder.Dependencies(networkClient: container.networkClient)
    )
    private lazy var newsCoordinator: NewsCoordinator = newsFeatureBuilder.makeCoordinator()
    private lazy var launchesCoordinator: LaunchesCoordinator = LaunchesFeatureBuilder(
        dependencies: LaunchesFeatureBuilder.Dependencies(
            networkClient: container.networkClient,
            modelContainer: container.modelContainer,
            newsRepository: newsFeatureBuilder.makeRepository()
        )
    )
    .makeCoordinator()

    init(container: AppContainer) {
        self.container = container
    }

    func makeRootView() -> AppRootView {
        AppRootView(
            launchesRootView: launchesCoordinator.makeRootView(),
            newsRootView: newsCoordinator.makeRootView()
        )
    }
}

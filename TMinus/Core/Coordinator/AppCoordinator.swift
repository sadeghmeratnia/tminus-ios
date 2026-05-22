//
//  AppCoordinator.swift
//  TMinus
//
//  Created by Sadegh on 07/05/2026.
//

import SwiftUI

@MainActor
final class AppCoordinator: CoordinatorProtocol {
    typealias RootView = ContentView

    private let container: AppContainer
    private lazy var launchesCoordinator: LaunchesCoordinator = LaunchesFeatureBuilder(container: container)
        .makeCoordinator()

    init(container: AppContainer) {
        self.container = container
    }

    func makeRootView() -> ContentView {
        launchesCoordinator.makeRootView()
    }
}

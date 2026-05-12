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

    private let launchesCoordinator: LaunchesCoordinator

    init(launchesCoordinator: LaunchesCoordinator) {
        self.launchesCoordinator = launchesCoordinator
    }

    func makeRootView() -> ContentView {
        launchesCoordinator.makeRootView()
    }
}

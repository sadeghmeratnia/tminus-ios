//
//  TMinusApp.swift
//  TMinus
//
//  Created by Sadegh on 22/04/2026.
//

import SwiftUI

@main
struct TMinusApp: App {
    private let appCoordinator: AppCoordinator

    init() {
        let container = DIContainer()
        appCoordinator = container.coordinatorFactory.makeAppCoordinator()
    }

    var body: some Scene {
        WindowGroup {
            appCoordinator.makeRootView()
        }
    }
}

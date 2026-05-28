//
//  LaunchesRootView.swift
//  TMinus
//
//  Created by Sadegh on 28/05/2026.
//

import SwiftUI

struct LaunchesRootView: View {
    @ObservedObject private var coordinator: LaunchesCoordinator

    init(coordinator: LaunchesCoordinator) {
        self.coordinator = coordinator
    }

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            coordinator.makeLaunchListView(onLaunchSelected: coordinator.showLaunchDetail(id:))
                .navigationDestination(for: LaunchesDestination.self) { destination in
                    coordinator.destinationView(for: destination)
                }
        }
    }
}

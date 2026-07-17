//
//  LaunchesCoordinator.swift
//  TMinus
//
//  Created by Sadegh on 07/05/2026.
//

import Combine
import SwiftUI

@MainActor
final class LaunchesCoordinator: ObservableObject, CoordinatorProtocol {
    typealias RootView = LaunchesRootView

    @Published var path = NavigationPath()

    private let launchListBuilder: LaunchListBuilding
    private let launchDetailBuilder: LaunchDetailBuilding

    init(launchListBuilder: LaunchListBuilding,
         launchDetailBuilder: LaunchDetailBuilding)
    {
        self.launchListBuilder = launchListBuilder
        self.launchDetailBuilder = launchDetailBuilder
    }

    func makeRootView() -> LaunchesRootView {
        LaunchesRootView(coordinator: self)
    }

    func makeLaunchListView(onLaunchSelected: @escaping (String) -> Void) -> DefaultLaunchListView {
        launchListBuilder.makeView(onLaunchSelected: onLaunchSelected)
    }

    func showLaunchDetail(id: String) {
        path.append(LaunchesDestination.launchDetail(id: id))
    }

    @ViewBuilder
    func destinationView(for destination: LaunchesDestination) -> some View {
        switch destination {
        case let .launchDetail(id):
            launchDetailBuilder.makeView(launchID: id)
        }
    }
}

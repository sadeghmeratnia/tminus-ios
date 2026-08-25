//
//  LaunchesCoordinator.swift
//  TMinus
//
//  Created by Sadegh on 07/05/2026.
//

import SwiftUI

final class LaunchesCoordinator: StackCoordinator<LaunchesDestination>, CoordinatorProtocol {
    typealias RootView = LaunchesRootView

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
        push(.launchDetail(id: id))
    }

    @ViewBuilder
    func destinationView(for destination: LaunchesDestination) -> some View {
        switch destination {
        case let .launchDetail(id):
            launchDetailBuilder.makeView(launchID: id)
        }
    }
}

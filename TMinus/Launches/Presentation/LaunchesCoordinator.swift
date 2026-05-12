//
//  LaunchesCoordinator.swift
//  TMinus
//
//  Created by Sadegh on 07/05/2026.
//

import SwiftUI

@MainActor
final class LaunchesCoordinator: CoordinatorProtocol {
    typealias RootView = ContentView

    private let viewModel: LaunchListViewModel

    init(viewModel: LaunchListViewModel) {
        self.viewModel = viewModel
    }

    func makeRootView() -> ContentView {
        ContentView(viewModel: viewModel)
    }
}

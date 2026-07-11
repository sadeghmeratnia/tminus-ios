//
//  LaunchListBuilder.swift
//  TMinus
//
//  Created by Sadegh on 28/05/2026.
//

import SwiftUI

@MainActor
protocol LaunchListBuilding: AnyObject {
    func makeView(onLaunchSelected: @escaping (String) -> Void) -> DefaultLaunchListView
}

@MainActor
final class LaunchListBuilder: LaunchListBuilding {
    private let viewModel: LaunchListViewModel

    init(viewModel: LaunchListViewModel) {
        self.viewModel = viewModel
    }

    func makeView(onLaunchSelected: @escaping (String) -> Void) -> DefaultLaunchListView {
        LaunchListView(viewModel: viewModel, onLaunchSelected: onLaunchSelected)
    }
}

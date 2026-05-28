//
//  LaunchListBuilder.swift
//  TMinus
//
//  Created by Sadegh on 28/05/2026.
//

import SwiftUI

@MainActor
protocol LaunchListBuilding: AnyObject {
    var viewModel: LaunchListViewModel { get }
    func makeView(onLaunchSelected: @escaping (String) -> Void) -> LaunchListView
}

@MainActor
final class LaunchListBuilder: LaunchListBuilding {
    let viewModel: LaunchListViewModel

    init(viewModel: LaunchListViewModel) {
        self.viewModel = viewModel
    }

    func makeView(onLaunchSelected: @escaping (String) -> Void) -> LaunchListView {
        LaunchListView(viewModel: viewModel, onLaunchSelected: onLaunchSelected)
    }
}

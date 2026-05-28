//
//  LaunchDetailBuilder.swift
//  TMinus
//
//  Created by Sadegh on 28/05/2026.
//

import SwiftUI

@MainActor
protocol LaunchDetailBuilding {
    func makeView(launchID: String) -> LaunchDetailView
}

@MainActor
final class LaunchDetailBuilder: LaunchDetailBuilding {
    private let fetchLaunchDetailUseCase: FetchLaunchDetailUseCase

    init(fetchLaunchDetailUseCase: FetchLaunchDetailUseCase) {
        self.fetchLaunchDetailUseCase = fetchLaunchDetailUseCase
    }

    func makeViewModel(launchID: String) -> LaunchDetailViewModel {
        LaunchDetailViewModel(
            launchID: launchID,
            fetchLaunchDetailUseCase: fetchLaunchDetailUseCase)
    }

    func makeView(launchID: String) -> LaunchDetailView {
        LaunchDetailView(viewModel: makeViewModel(launchID: launchID))
    }
}

//
//  LaunchDetailBuilder.swift
//  TMinus
//
//  Created by Sadegh on 28/05/2026.
//

import SwiftUI

@MainActor
protocol LaunchDetailBuilding {
    func makeView(launchID: String) -> DefaultLaunchDetailView
}

@MainActor
final class LaunchDetailBuilder: LaunchDetailBuilding {
    private let fetchLaunchDetailUseCase: FetchLaunchDetailUseCase
    private let fetchRelatedNewsUseCase: FetchRelatedNewsUseCase

    init(fetchLaunchDetailUseCase: FetchLaunchDetailUseCase,
         fetchRelatedNewsUseCase: FetchRelatedNewsUseCase) {
        self.fetchLaunchDetailUseCase = fetchLaunchDetailUseCase
        self.fetchRelatedNewsUseCase = fetchRelatedNewsUseCase
    }

    private func makeViewModel(launchID: String) -> LaunchDetailViewModel {
        LaunchDetailViewModel(
            launchID: launchID,
            fetchLaunchDetailUseCase: fetchLaunchDetailUseCase,
            fetchRelatedNewsUseCase: fetchRelatedNewsUseCase)
    }

    func makeView(launchID: String) -> DefaultLaunchDetailView {
        LaunchDetailView(viewModel: makeViewModel(launchID: launchID))
    }
}

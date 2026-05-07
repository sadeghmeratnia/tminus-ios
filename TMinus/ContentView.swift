//
//  ContentView.swift
//  TMinus
//
//  Created by Sadegh on 22/04/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel: LaunchListViewModel

    init(container: DIContainer) {
        _viewModel = State(
            initialValue: LaunchListViewModel(
                fetchUpcomingLaunchesUseCase: container.fetchUpcomingLaunchesUseCase,
                fetchPreviousLaunchesUseCase: container.fetchPreviousLaunchesUseCase))
    }

    var body: some View {
        LaunchListView(viewModel: viewModel)
    }
}

#Preview {
    ContentView(container: DIContainer())
}

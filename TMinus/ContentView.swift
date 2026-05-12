//
//  ContentView.swift
//  TMinus
//
//  Created by Sadegh on 22/04/2026.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: LaunchListViewModel

    var body: some View {
        LaunchListView(viewModel: viewModel)
    }
}

#Preview {
    let container = DIContainer()
    let viewModel = LaunchListViewModel(
        fetchUpcomingLaunchesUseCase: container.fetchUpcomingLaunchesUseCase,
        fetchPreviousLaunchesUseCase: container.fetchPreviousLaunchesUseCase
    )
    ContentView(viewModel: viewModel)
}

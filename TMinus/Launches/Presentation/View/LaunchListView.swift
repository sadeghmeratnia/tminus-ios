//
//  LaunchListView.swift
//  TMinus
//
//  Created by Sadegh on 06/05/2026.
//

import SwiftUI

// MARK: - LaunchListView

struct LaunchListView: View {
    @ObservedObject var viewModel: LaunchListViewModel

    private var state: LaunchListViewModel.State {
        viewModel.state
    }

    private var launches: [Launch] {
        state.launches
    }

    private var emptyErrorMessage: String? {
        if case let .error(_, message, launchesInErrorState) = state, launchesInErrorState.isEmpty {
            return message
        }
        return nil
    }

    private var modeBinding: Binding<LaunchListViewModel.Mode> {
        Binding(
            get: { state.mode },
            set: { viewModel.onTrigger(.modeChanged($0)) })
    }

    var body: some View {
        NavigationStack {
            contentView
                .background(Color(.systemGroupedBackground))
                .navigationTitle(L10n.Launches.navigationTitle)
                .navigationBarTitleDisplayMode(.large)
                .task { viewModel.onTrigger(.onAppear) }
        }
    }

    private var contentView: some View {
        Group {
            if case .loading = state, launches.isEmpty {
                loadingView
            } else if let errorMessage = emptyErrorMessage {
                errorView(message: errorMessage)
            } else if launches.isEmpty {
                emptyView
            } else {
                launchesListView
            }
        }
    }

    private var loadingView: some View {
        ProgressView(L10n.Launches.loading)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        ContentUnavailableView(
            L10n.Launches.errorTitle,
            systemImage: Constants.Icon.error,
            description: Text(message))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        ContentUnavailableView(
            L10n.Launches.emptyTitle,
            systemImage: Constants.Icon.empty,
            description: Text(L10n.Launches.emptyDescription))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var launchesListView: some View {
        ScrollView {
            VStack(spacing: UIConstants.Spacing.large) {
                Picker(L10n.Launches.modePicker, selection: modeBinding) {
                    ForEach(LaunchListViewModel.Mode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                ForEach(launches) { launch in
                    LaunchCardView(launch: launch)
                }
            }
            .padding(.horizontal, UIConstants.Padding.horizontal)
            .padding(.vertical, UIConstants.Padding.vertical)
        }
        .refreshable { viewModel.onTrigger(.refresh) }
    }
}

// MARK: - Constants

private enum Constants {
    enum Icon {
        static let error = "wifi.exclamationmark"
        static let empty = "moon.stars.fill"
    }
}

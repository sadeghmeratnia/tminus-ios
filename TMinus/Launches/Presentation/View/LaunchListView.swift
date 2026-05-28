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
        if case let .error(_, message, launchesInErrorState, _) = state, launchesInErrorState.isEmpty {
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

    private func loadMoreErrorFooter(message: String) -> some View {
        VStack(spacing: UIConstants.Spacing.small) {
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                viewModel.onTrigger(.retryLoadMore)
            } label: {
                Label(L10n.Launches.retryAction, systemImage: Constants.Icon.retry)
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, UIConstants.Padding.vertical)
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
            LazyVStack(spacing: UIConstants.Spacing.large) {
                Picker(L10n.Launches.modePicker, selection: modeBinding) {
                    ForEach(LaunchListViewModel.Mode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                ForEach(launches) { launch in
                    LaunchCardView(launch: launch)
                        .onAppear { viewModel.onTrigger(.launchAppeared(launch.id)) }
                }

                if state.pagination.isLoadingMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if let loadMoreError = state.pagination.loadMoreError {
                    loadMoreErrorFooter(message: loadMoreError)
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
        static let retry = "arrow.clockwise"
    }
}

#Preview {
    let container = AppContainer.preview()
    let coordinator = LaunchesFeatureBuilder(
        dependencies: .init(
            networkClient: container.networkClient,
            modelContainer: container.modelContainer))
        .makeCoordinator()
    coordinator.makeRootView()
}

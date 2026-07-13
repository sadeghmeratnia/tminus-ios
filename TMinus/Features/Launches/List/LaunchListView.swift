//
//  LaunchListView.swift
//  TMinus
//
//  Created by Sadegh on 06/05/2026.
//

import SwiftUI

// MARK: - LaunchListView

struct LaunchListView<VM: LaunchListViewModelProtocol>: View {
    @ObservedObject var viewModel: VM
    let onLaunchSelected: (String) -> Void

    private var state: LaunchListState {
        viewModel.state
    }

    private var launches: [Launch] {
        state.launches
    }

    private var contentPhase: ListContentPhase<Launch> {
        .derive(phase: state.phase, items: launches)
    }

    private var refreshBannerMessage: String? {
        ListContentPhase.refreshErrorMessage(phase: state.phase, items: launches)
    }

    private var modeBinding: Binding<LaunchListMode> {
        Binding(
            get: { state.mode },
            set: { viewModel.onTrigger(.modeChanged($0)) })
    }

    var body: some View {
        contentView
            .background(Color(.systemGroupedBackground))
            .navigationTitle(L10n.Launches.navigationTitle)
            .navigationBarTitleDisplayMode(.large)
            .task { viewModel.onTrigger(.onAppear) }
    }

    private var contentView: some View {
        Group {
            switch contentPhase {
            case .loading:
                loadingView
            case let .error(message):
                errorView(message: message)
            case .empty:
                emptyView
            case .content:
                launchesListView(bannerMessage: refreshBannerMessage)
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
            systemImage: UIConstants.Icon.networkError,
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

    private func launchesListView(bannerMessage: String?) -> some View {
        ScrollView {
            LazyVStack(spacing: UIConstants.Spacing.large) {
                Picker(L10n.Launches.modePicker, selection: modeBinding) {
                    ForEach(LaunchListMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if let bannerMessage {
                    ListRefreshErrorBanner(
                        message: bannerMessage,
                        retryTitle: L10n.Launches.retryAction,
                        onRetry: { viewModel.onTrigger(.refresh) })
                }

                ForEach(launches) { launch in
                    Button {
                        onLaunchSelected(launch.id)
                    } label: {
                        LaunchCardView(launch: launch)
                    }
                    .buttonStyle(.plain)
                    .onAppear { viewModel.onTrigger(.launchAppeared(launch.id)) }
                }

                if case .loading(.loadMore) = state.phase {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if let loadMoreError = state.pagination.loadMoreError {
                    ListLoadMoreErrorFooter(
                        message: loadMoreError,
                        retryTitle: L10n.Launches.retryAction,
                        onRetry: { viewModel.onTrigger(.retryLoadMore) })
                }
            }
            .padding(.horizontal, UIConstants.Padding.horizontal)
            .padding(.vertical, UIConstants.Padding.vertical)
        }
        .refreshable { viewModel.onTrigger(.refresh) }
    }
}

typealias DefaultLaunchListView = LaunchListView<LaunchListViewModel>

// MARK: - Constants

private enum Constants {
    enum Icon {
        static let empty = "moon.stars.fill"
    }
}

// MARK: - Previews

#Preview("Loaded") {
    NavigationStack {
        LaunchListView(
            viewModel: StaticViewModel(state: LaunchPreviewFixtures.listLoadedState),
            onLaunchSelected: { _ in })
    }
}

#Preview("Loading") {
    NavigationStack {
        LaunchListView(
            viewModel: StaticViewModel(
                state: LaunchListState(
                    mode: .upcoming,
                    launches: [],
                    pagination: .initial,
                    phase: .loading(.initial))),
            onLaunchSelected: { _ in })
    }
}

#Preview("Error") {
    NavigationStack {
        LaunchListView(
            viewModel: StaticViewModel(
                state: LaunchListState(
                    mode: .upcoming,
                    launches: [],
                    pagination: .initial,
                    phase: .error(message: "Could not load launches"))),
            onLaunchSelected: { _ in })
    }
}

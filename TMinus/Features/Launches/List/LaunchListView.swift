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

    private var resolvedContent: (phase: ListContentPhase<Launch>, refreshErrorMessage: String?) {
        ListContentPhase.resolve(phase: state.phase, items: launches)
    }

    private var modeBinding: Binding<LaunchListMode> {
        Binding(
            get: { state.mode },
            set: { viewModel.onTrigger(.modeChanged($0)) })
    }

    var body: some View {
        let (phase, refreshErrorMessage) = resolvedContent
        return VStack(spacing: 0) {
            modePicker
            ListScreenScaffold(
                phase: phase,
                loadingTitle: L10n.Launches.loading,
                errorTitle: L10n.Launches.errorTitle,
                emptyTitle: L10n.Launches.emptyTitle,
                emptyDescription: L10n.Launches.emptyDescription,
                emptyIcon: Constants.Icon.empty) {
                    launchesListView(bannerMessage: refreshErrorMessage)
                }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(L10n.Launches.navigationTitle)
        .navigationBarTitleDisplayMode(.large)
        .task { viewModel.onTrigger(.onAppear) }
    }

    private var modePicker: some View {
        Picker(L10n.Launches.modePicker, selection: modeBinding) {
            ForEach(LaunchListMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, UIConstants.Padding.horizontal)
        .padding(.vertical, UIConstants.Padding.vertical)
    }

    private func launchesListView(bannerMessage: String?) -> some View {
        ScrollView {
            LazyVStack(spacing: UIConstants.Spacing.large) {
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

                ListLoadMoreFooter(
                    isLoadingMore: state.phase.isLoadingMore,
                    loadMoreError: state.pagination.loadMoreError,
                    retryTitle: L10n.Launches.retryAction,
                    onRetry: { viewModel.onTrigger(.retryLoadMore) })
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

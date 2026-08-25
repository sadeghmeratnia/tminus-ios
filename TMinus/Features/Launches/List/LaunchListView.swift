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
            set: { viewModel.onTrigger(.modeChanged($0)) }
        )
    }

    private var searchBinding: Binding<String> {
        Binding(
            get: { state.searchText },
            set: { viewModel.onTrigger(.searchTextChanged($0)) }
        )
    }

    var body: some View {
        let (phase, refreshErrorMessage) = resolvedContent
        let isSearching = state.searchText.isEmpty == false
        return VStack(spacing: 0) {
            modePicker
            ListScreenScaffold(
                phase: phase,
                loadingTitle: L10n.Launches.loading,
                errorTitle: L10n.Launches.errorTitle,
                emptyTitle: isSearching ? L10n.Launches.noResultsTitle : L10n.Launches.emptyTitle,
                emptyDescription: isSearching ? L10n.Launches.noResultsDescription : L10n.Launches.emptyDescription,
                emptyIcon: isSearching ? Constants.Icon.noResults : Constants.Icon.empty,
                retry: (title: L10n.Launches.retryAction, action: { viewModel.onTrigger(.retry) })
            ) {
                launchesListView(bannerMessage: refreshErrorMessage)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(L10n.Launches.navigationTitle)
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: searchBinding, prompt: L10n.Launches.searchPrompt)
        .task { viewModel.onTrigger(.onAppear) }
        .onDisappear { viewModel.cancelInFlightWork() }
    }

    private var modePicker: some View {
        Picker(L10n.Launches.modePicker, selection: modeBinding) {
            ForEach(LaunchListMode.allCases) { mode in
                // `.segmented` is a fixed-height UIKit control that doesn't grow with Dynamic
                // Type, at large accessibility text sizes it clips/truncates a label instead of
                // wrapping. `.minimumScaleFactor` lets the segment shrink the text down rather
                // than clip it; that's a real tradeoff (very large settings do make the label
                // smaller than the user's chosen size), but a shrunk-but-fully-legible label beats
                // a clipped one.
                Text(mode.title)
                    .minimumScaleFactor(Constants.modeTitleMinimumScaleFactor)
                    .tag(mode)
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
                        onRetry: { viewModel.onTrigger(.refresh) }
                    )
                }

                ForEach(launches) { launch in
                    Button {
                        onLaunchSelected(launch.id)
                    } label: {
                        LaunchCardView(launch: launch)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(Constants.AccessibilityID.launchCard)
                    .onAppear { viewModel.onTrigger(.launchAppeared(launch.id)) }
                }

                ListLoadMoreFooter(
                    isLoadingMore: state.phase.isLoadingMore,
                    loadMoreError: state.pagination.loadMoreError,
                    retryTitle: L10n.Launches.retryAction,
                    onRetry: { viewModel.onTrigger(.retryLoadMore) }
                )
            }
            .padding(.horizontal, UIConstants.Padding.horizontal)
            .padding(.vertical, UIConstants.Padding.vertical)
        }
        .refreshable { await viewModel.refresh() }
    }
}

typealias DefaultLaunchListView = LaunchListView<LaunchListViewModel>

// MARK: - Constants

private enum Constants {
    static let modeTitleMinimumScaleFactor: CGFloat = 0.6

    enum Icon {
        static let empty = "moon.stars.fill"
        static let noResults = "magnifyingglass"
    }

    enum AccessibilityID {
        static let launchCard = "launchCard"
    }
}

// MARK: - Previews

#Preview("Loaded") {
    NavigationStack {
        LaunchListView(
            viewModel: StaticViewModel(state: LaunchPreviewFixtures.listLoadedState),
            onLaunchSelected: { _ in }
        )
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
                    phase: .loading(.initial)
                )
            ),
            onLaunchSelected: { _ in }
        )
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
                    phase: .error(message: "Could not load launches")
                )
            ),
            onLaunchSelected: { _ in }
        )
    }
}

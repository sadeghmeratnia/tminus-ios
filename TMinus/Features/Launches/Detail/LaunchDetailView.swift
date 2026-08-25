//
//  LaunchDetailView.swift
//  TMinus
//
//  Created by Sadegh on 28/05/2026.
//

import SwiftUI

// MARK: - LaunchDetailView

struct LaunchDetailView<VM: LaunchDetailViewModelProtocol>: View {
    @ObservedObject var viewModel: VM

    private var state: LaunchDetailState {
        viewModel.state
    }

    var body: some View {
        Group {
            switch state.phase {
            case .idle, .loading:
                ProgressView(L10n.Launches.loading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .loaded:
                // `LaunchDetailReducer`/`LaunchDetailState.applyingLoadResponse` only ever set
                // `phase = .loaded` together with a non-nil `launch` in the same update, so the
                // `else` below is unreachable today, kept as defense-in-depth (a view crashing
                // on a force-unwrap is worse than a view falling back to an error state) rather
                // than force-unwrapping `state.launch!`.
                if let launch = state.launch {
                    detailContent(for: launch)
                } else {
                    errorView(message: L10n.Error.Network.unknown)
                }

            case let .error(message):
                errorView(message: message)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.onTrigger(.onAppear) }
        .onDisappear { viewModel.cancelInFlightWork() }
    }

    private func detailContent(for launch: Launch) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: UIConstants.Spacing.large) {
                if let refreshError = state.refreshError {
                    ListRefreshErrorBanner(
                        message: refreshError,
                        retryTitle: L10n.Launches.retryAction,
                        onRetry: { viewModel.onTrigger(.refresh) }
                    )
                }

                headerSection(for: launch)
                metadataSection(for: launch)

                if let missionDescription = launch.mission?.description, missionDescription.isEmpty == false {
                    missionSection(description: missionDescription)
                }

                if let webcastURL = launch.webcastURL {
                    Link(destination: webcastURL) {
                        Label(L10n.Launches.Detail.watchWebcast, systemImage: Constants.Icon.webcast)
                            .font(.subheadline.weight(.medium))
                    }
                }

                if state.relatedArticles.isEmpty == false {
                    relatedNewsSection
                }
            }
            .padding(.horizontal, UIConstants.Padding.horizontal)
            .padding(.vertical, UIConstants.Padding.vertical)
        }
        .refreshable { await viewModel.refresh() }
        .navigationTitle(launch.name)
        .accessibilityIdentifier(Constants.AccessibilityID.detailContent)
    }

    private func headerSection(for launch: Launch) -> some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.medium) {
            HeroImageView(imageURL: launch.imageURL)

            StatusPill(status: launch.status)
        }
    }

    private func metadataSection(for launch: Launch) -> some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.small) {
            if let rocketName = launch.rocket?.name {
                metadataRow(title: L10n.Launches.Detail.rocket, value: rocketName)
            }

            if let padName = launch.launchPad?.name {
                metadataRow(title: L10n.Launches.Detail.launchPad, value: padName)
            }

            if let locationName = launch.launchPad?.locationName {
                metadataRow(title: L10n.Launches.Detail.location, value: locationName)
            }

            metadataRow(
                title: L10n.Launches.Detail.windowStart,
                value: launch.windowStart.formatted(Constants.windowDateStyle)
            )

            if let windowEnd = launch.windowEnd {
                metadataRow(
                    title: L10n.Launches.Detail.windowEnd,
                    value: windowEnd.formatted(Constants.windowDateStyle)
                )
            }

            if let missionName = launch.mission?.name {
                metadataRow(title: L10n.Launches.Detail.mission, value: missionName)
            }

            if let missionType = launch.mission?.type {
                metadataRow(title: L10n.Launches.Detail.missionType, value: missionType)
            }

            if let orbit = launch.mission?.orbit {
                metadataRow(title: L10n.Launches.Detail.orbit, value: orbit)
            }
        }
        .padding(UIConstants.Padding.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: UIConstants.CornerRadius.card, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func missionSection(description: String) -> some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.small) {
            Text(L10n.Launches.Detail.missionDescription)
                .font(.headline)

            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(UIConstants.Padding.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: UIConstants.CornerRadius.card, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .accessibilityElement(children: .combine)
    }

    private var relatedNewsSection: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.medium) {
            Text(L10n.Launches.Detail.relatedNewsTitle)
                .font(.headline)

            ForEach(state.relatedArticles) { article in
                Link(destination: article.url) {
                    relatedNewsRow(for: article)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func relatedNewsRow(for article: NewsArticle) -> some View {
        HStack(alignment: .top, spacing: UIConstants.Spacing.small) {
            Image(systemName: Constants.Icon.relatedNews)
                .foregroundStyle(.secondary)
                // Decorative, the row's title/site text already conveys "this is a news item".
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: UIConstants.Spacing.xSmall) {
                Text(article.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(article.newsSite)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(UIConstants.Padding.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: UIConstants.CornerRadius.card, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        // Merges title + site into a single announcement for this `Link` row instead of two.
        .accessibilityElement(children: .combine)
    }

    private func metadataRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.small) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline)
        }
        // Merges the caption label and value into one announcement (e.g. "Rocket, Falcon 9
        // Block 5") instead of two separate swipe stops per row.
        .accessibilityElement(children: .combine)
    }

    private func errorView(message: String) -> some View {
        ContentUnavailableView {
            Label(L10n.Launches.errorTitle, systemImage: UIConstants.Icon.networkError)
        } description: {
            Text(message)
        } actions: {
            Button(L10n.Launches.retryAction) {
                viewModel.onTrigger(.retry)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier(Constants.AccessibilityID.retryButton)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

typealias DefaultLaunchDetailView = LaunchDetailView<LaunchDetailViewModel>

// MARK: - Constants

private enum Constants {
    enum AccessibilityID {
        static let detailContent = "launchDetailContent"
        static let retryButton = "launchDetailRetryButton"
    }

    enum Icon {
        static let webcast = "play.rectangle"
        static let relatedNews = "newspaper"
    }

    static let windowDateStyle = Date.FormatStyle(
        date: .complete,
        time: .shortened
    )
}

// MARK: - Previews

#Preview("Loaded") {
    NavigationStack {
        LaunchDetailView(
            viewModel: StaticViewModel(state: LaunchPreviewFixtures.detailLoadedState)
        )
    }
}

#Preview("Loading") {
    NavigationStack {
        LaunchDetailView(
            viewModel: StaticViewModel(
                state: LaunchDetailState(
                    launchID: LaunchPreviewFixtures.launchID,
                    launch: nil,
                    phase: .loading,
                    relatedArticles: [],
                    loadGeneration: LoadGeneration(current: 1),
                    relatedNewsGeneration: LoadGeneration(current: 1),
                    relatedNewsHasLoaded: false,
                    refreshError: nil
                )
            )
        )
    }
}

#Preview("Error") {
    NavigationStack {
        LaunchDetailView(
            viewModel: StaticViewModel(
                state: LaunchDetailState(
                    launchID: LaunchPreviewFixtures.launchID,
                    launch: nil,
                    phase: .error(message: "Could not load launch details"),
                    relatedArticles: [],
                    loadGeneration: LoadGeneration(current: 1),
                    relatedNewsGeneration: LoadGeneration(current: 1),
                    relatedNewsHasLoaded: false,
                    refreshError: nil
                )
            )
        )
    }
}

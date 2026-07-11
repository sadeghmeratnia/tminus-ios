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
    }

    @ViewBuilder
    private func detailContent(for launch: Launch) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: UIConstants.Spacing.large) {
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
        .navigationTitle(launch.name)
    }

    private func headerSection(for launch: Launch) -> some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.medium) {
            AsyncImage(url: launch.imageURL) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    Rectangle()
                        .fill(Color.secondary.opacity(UIConstants.Opacity.subtleBackground))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: Constants.Layout.heroHeight)
            .clipShape(RoundedRectangle(cornerRadius: UIConstants.CornerRadius.card, style: .continuous))

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
                value: launch.windowStart.formatted(Constants.windowDateStyle))

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
                .fill(Color(.secondarySystemGroupedBackground)))
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
                .fill(Color(.secondarySystemGroupedBackground)))
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
                .fill(Color(.secondarySystemGroupedBackground)))
    }

    private func metadataRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.small) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline)
        }
    }

    private func errorView(message: String) -> some View {
        ContentUnavailableView {
            Label(L10n.Launches.errorTitle, systemImage: Constants.Icon.error)
        } description: {
            Text(message)
        } actions: {
            Button(L10n.Launches.retryAction) {
                viewModel.onTrigger(.retry)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

typealias DefaultLaunchDetailView = LaunchDetailView<LaunchDetailViewModel>

// MARK: - Constants

private enum Constants {
    enum Layout {
        static let heroHeight: CGFloat = 220
    }

    enum Icon {
        static let error = "wifi.exclamationmark"
        static let webcast = "play.rectangle"
        static let relatedNews = "newspaper"
    }

    static let windowDateStyle = Date.FormatStyle(
        date: .complete,
        time: .shortened)
}

// MARK: - Previews

#Preview("Loaded") {
    NavigationStack {
        LaunchDetailView(
            viewModel: StaticViewModel(state: LaunchPreviewFixtures.detailLoadedState))
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
                    relatedArticles: [])))
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
                    relatedArticles: [])))
    }
}

//
//  NewsDetailView.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import SwiftUI

// MARK: - NewsDetailView

struct NewsDetailView<VM: NewsDetailViewModelProtocol>: View {
    @ObservedObject var viewModel: VM

    private var state: NewsDetailState {
        viewModel.state
    }

    var body: some View {
        Group {
            switch state.phase {
            case .idle, .loading:
                ProgressView(L10n.News.loading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .loaded:
                // See `LaunchDetailView`'s equivalent, `NewsDetailReducer`/`NewsDetailState`
                // only ever set `phase = .loaded` together with a non-nil `article`, so the
                // `else` below is unreachable today, kept as defense-in-depth rather than a
                // force-unwrap.
                if let article = state.article {
                    detailContent(for: article)
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

    private func detailContent(for article: NewsArticle) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: UIConstants.Spacing.large) {
                if let refreshError = state.refreshError {
                    ListRefreshErrorBanner(
                        message: refreshError,
                        retryTitle: L10n.News.retryAction,
                        onRetry: { viewModel.onTrigger(.refresh) }
                    )
                }

                headerSection(for: article)
                metadataSection(for: article)
                summarySection(for: article)

                Link(destination: article.url) {
                    Label(L10n.News.Detail.readFullArticle, systemImage: Constants.Icon.link)
                        .font(.subheadline.weight(.medium))
                }
            }
            .padding(.horizontal, UIConstants.Padding.horizontal)
            .padding(.vertical, UIConstants.Padding.vertical)
        }
        .refreshable { await viewModel.refresh() }
        .navigationTitle(article.newsSite)
        .accessibilityIdentifier(Constants.AccessibilityID.detailContent)
    }

    private func headerSection(for article: NewsArticle) -> some View {
        HeroImageView(imageURL: article.imageURL)
    }

    private func metadataSection(for article: NewsArticle) -> some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.small) {
            Text(article.title)
                .font(.title2.weight(.semibold))

            Label(article.newsSite, systemImage: Constants.Icon.newsSite)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Label(
                article.publishedAt.formatted(Constants.publishedDateStyle),
                systemImage: UIConstants.Icon.calendar
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Merges title + site + published-date into one VoiceOver stop instead of three separate
        // swipes, matches `LaunchDetailView`'s equivalent metadata rows.
        .accessibilityElement(children: .combine)
    }

    private func summarySection(for article: NewsArticle) -> some View {
        Text(article.summary)
            .font(.body)
            .foregroundStyle(.secondary)
            .padding(UIConstants.Padding.card)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: UIConstants.CornerRadius.card, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
    }

    private func errorView(message: String) -> some View {
        ContentUnavailableView {
            Label(L10n.News.errorTitle, systemImage: UIConstants.Icon.networkError)
        } description: {
            Text(message)
        } actions: {
            Button(L10n.News.retryAction) {
                viewModel.onTrigger(.retry)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier(Constants.AccessibilityID.retryButton)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

typealias DefaultNewsDetailView = NewsDetailView<NewsDetailViewModel>

// MARK: - Constants

private enum Constants {
    enum Icon {
        static let link = "safari"
        static let newsSite = "newspaper"
    }

    enum AccessibilityID {
        static let detailContent = "newsDetailContent"
        static let retryButton = "newsDetailRetryButton"
    }

    static let publishedDateStyle = Date.FormatStyle(
        date: .complete,
        time: .shortened
    )
}

// MARK: - Previews

#Preview("Loaded") {
    NavigationStack {
        NewsDetailView(
            viewModel: StaticViewModel(state: NewsPreviewFixtures.detailLoadedState)
        )
    }
}

#Preview("Loading") {
    NavigationStack {
        NewsDetailView(
            viewModel: StaticViewModel(
                state: NewsDetailState(
                    articleID: NewsPreviewFixtures.articleID,
                    article: nil,
                    phase: .loading,
                    loadGeneration: LoadGeneration(current: 1),
                    refreshError: nil
                )
            )
        )
    }
}

#Preview("Error") {
    NavigationStack {
        NewsDetailView(
            viewModel: StaticViewModel(
                state: NewsDetailState(
                    articleID: NewsPreviewFixtures.articleID,
                    article: nil,
                    phase: .error(message: "Could not load article"),
                    loadGeneration: LoadGeneration(current: 1),
                    refreshError: nil
                )
            )
        )
    }
}

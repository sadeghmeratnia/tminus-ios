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
    }

    @ViewBuilder
    private func detailContent(for article: NewsArticle) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: UIConstants.Spacing.large) {
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
        .navigationTitle(article.newsSite)
    }

    private func headerSection(for article: NewsArticle) -> some View {
        AsyncImage(url: article.imageURL) { phase in
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
                systemImage: Constants.Icon.calendar)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func summarySection(for article: NewsArticle) -> some View {
        Text(article.summary)
            .font(.body)
            .foregroundStyle(.secondary)
            .padding(UIConstants.Padding.card)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: UIConstants.CornerRadius.card, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground)))
    }

    private func errorView(message: String) -> some View {
        ContentUnavailableView {
            Label(L10n.News.errorTitle, systemImage: Constants.Icon.error)
        } description: {
            Text(message)
        } actions: {
            Button(L10n.News.retryAction) {
                viewModel.onTrigger(.retry)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

typealias DefaultNewsDetailView = NewsDetailView<NewsDetailViewModel>

// MARK: - Constants

private enum Constants {
    enum Layout {
        static let heroHeight: CGFloat = 220
    }

    enum Icon {
        static let error = "wifi.exclamationmark"
        static let link = "safari"
        static let newsSite = "newspaper"
        static let calendar = "calendar"
    }

    static let publishedDateStyle = Date.FormatStyle(
        date: .complete,
        time: .shortened)
}

// MARK: - Previews

#Preview("Loaded") {
    NavigationStack {
        NewsDetailView(
            viewModel: StaticViewModel(state: NewsPreviewFixtures.detailLoadedState))
    }
}

#Preview("Loading") {
    NavigationStack {
        NewsDetailView(
            viewModel: StaticViewModel(
                state: NewsDetailState(
                    articleID: NewsPreviewFixtures.articleID,
                    article: nil,
                    phase: .loading)))
    }
}

#Preview("Error") {
    NavigationStack {
        NewsDetailView(
            viewModel: StaticViewModel(
                state: NewsDetailState(
                    articleID: NewsPreviewFixtures.articleID,
                    article: nil,
                    phase: .error(message: "Could not load article"))))
    }
}

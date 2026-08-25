//
//  NewsCardView.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import SwiftUI

// MARK: - NewsCardView

struct NewsCardView: View {
    let article: NewsArticle

    var body: some View {
        MediaCardView(imageURL: article.imageURL) {
            infoView
        }
    }

    private var infoView: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.small) {
            Text(article.title)
                .font(.headline)
                .lineLimit(UIConstants.Layout.titleLineLimit)

            Text(article.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(Constants.metadataLineLimit)

            metadataRow
        }
    }

    private var metadataRow: some View {
        // `ViewThatFits` falls back to the stacked layout whenever the side-by-side row can't fit
        // both labels at their natural size, at large Dynamic Type sizes, `icon + newsSite` and
        // `icon + date` can each already approach the card's full width on their own, so forcing
        // them onto one row (as a bare `HStack` did previously, via `.fixedSize()` on the date)
        // let the row overflow the card's bounds instead of degrading gracefully.
        ViewThatFits(in: .horizontal) {
            metadataHStack
            metadataVStack
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var metadataHStack: some View {
        HStack(spacing: UIConstants.Spacing.small) {
            // A long `newsSite` name and the date compete for the same row width with no fixed
            // sizing on either, without an explicit priority, SwiftUI can shrink/clip whichever
            // one it likes, including the date. The date is the shorter, format-stable string of
            // the two, so it's given priority to stay whole; the site name is the one allowed to
            // truncate under pressure.
            newsSiteLabel
                .lineLimit(1)
                .truncationMode(.tail)
            dateLabel
                .lineLimit(1)
                .layoutPriority(1)
        }
    }

    private var metadataVStack: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.small / 2) {
            newsSiteLabel
                .lineLimit(1)
                .truncationMode(.tail)
            dateLabel
                .lineLimit(1)
        }
    }

    private var newsSiteLabel: some View {
        Label(article.newsSite, systemImage: Constants.Icon.newsSite)
    }

    private var dateLabel: some View {
        Label(article.publishedAt.formatted(Constants.publishedDateStyle), systemImage: UIConstants.Icon.calendar)
    }
}

// MARK: - Constants

private enum Constants {
    static let metadataLineLimit = 2

    enum Icon {
        static let newsSite = "newspaper"
    }

    static let publishedDateStyle = Date.FormatStyle()
        .month().day().year()
}

// MARK: - Previews

#Preview("Loaded") {
    NewsCardView(article: NewsPreviewFixtures.article)
        .padding()
}

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
        HStack(alignment: .top, spacing: UIConstants.Spacing.medium) {
            thumbnailView
            infoView
        }
        .padding(UIConstants.Padding.card)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundView)
        .overlay(overlayView)
    }

    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: UIConstants.CornerRadius.card, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
    }

    private var overlayView: some View {
        RoundedRectangle(cornerRadius: UIConstants.CornerRadius.card, style: .continuous)
            .stroke(Color.primary.opacity(UIConstants.Border.opacity), lineWidth: UIConstants.Border.lineWidth)
    }

    private var thumbnailView: some View {
        AsyncImage(url: article.imageURL) { phase in
            switch phase {
            case let .success(image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                placeholderImage
            case .empty:
                Rectangle()
                    .fill(Color.secondary.opacity(UIConstants.Opacity.subtleBackground))
            @unknown default:
                placeholderImage
            }
        }
        .frame(width: Constants.Layout.thumbnailSize, height: Constants.Layout.thumbnailSize)
        .clipShape(RoundedRectangle(cornerRadius: UIConstants.CornerRadius.image, style: .continuous))
    }

    private var infoView: some View {
        VStack(alignment: .leading, spacing: UIConstants.Spacing.small) {
            Text(article.title)
                .font(.headline)
                .lineLimit(Constants.Layout.titleLineLimit)

            Text(article.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(Constants.Layout.metadataLineLimit)

            metadataRow
        }
    }

    private var metadataRow: some View {
        HStack(spacing: UIConstants.Spacing.small) {
            Label(article.newsSite, systemImage: Constants.Icon.newsSite)
            Label(article.publishedAt.formatted(Constants.publishedDateStyle), systemImage: UIConstants.Icon.calendar)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    private var placeholderImage: some View {
        ZStack {
            Rectangle()
                .fill(Color.secondary.opacity(UIConstants.Opacity.subtleBackground))

            Image(systemName: UIConstants.Icon.photoPlaceholder)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Constants

private enum Constants {
    enum Layout {
        static let thumbnailSize: CGFloat = 84
        static let titleLineLimit = 2
        static let metadataLineLimit = 2
    }

    enum Icon {
        static let newsSite = "newspaper"
    }

    static let publishedDateStyle = Date.FormatStyle()
        .month().day().year()
}

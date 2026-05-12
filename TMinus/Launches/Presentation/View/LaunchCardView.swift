//
//  LaunchCardView.swift
//  TMinus
//
//  Created by Sadegh on 07/05/2026.
//

import SwiftUI

// MARK: - LaunchCardView

struct LaunchCardView: View {
    let launch: Launch

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
        AsyncImage(url: launch.imageURL) { phase in
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
            titleRow
            rocketView
            launchPadView
            launchDateView
        }
    }

    private var titleRow: some View {
        HStack(alignment: .top, spacing: UIConstants.Spacing.small) {
            Text(launch.name)
                .font(.headline)
                .lineLimit(Constants.Layout.titleLineLimit)

            Spacer(minLength: UIConstants.Spacing.small)

            StatusPill(status: launch.status)
        }
    }

    private var rocketView: some View {
        Text(launch.rocket.name)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(Constants.Layout.metadataLineLimit)
    }

    private var launchPadView: some View {
        Label(launch.launchPad.name, systemImage: Constants.Icon.launchPad)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(Constants.Layout.metadataLineLimit)
    }

    private var launchDateView: some View {
        Label(Self.dateFormatter.string(from: launch.windowStart), systemImage: Constants.Icon.calendar)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var placeholderImage: some View {
        ZStack {
            Rectangle()
                .fill(Color.secondary.opacity(UIConstants.Opacity.subtleBackground))

            Image(systemName: Constants.Icon.placeholder)
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
        static let metadataLineLimit = 1
    }

    enum Icon {
        static let launchPad = "mappin.and.ellipse"
        static let calendar = "calendar"
        static let placeholder = "photo"
    }
}

extension LaunchCardView {
    fileprivate static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

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
        MediaCardView(imageURL: launch.imageURL) {
            infoView
        }
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
                .lineLimit(UIConstants.Layout.titleLineLimit)

            Spacer(minLength: UIConstants.Spacing.small)

            StatusPill(status: launch.status)
        }
    }

    @ViewBuilder
    private var rocketView: some View {
        if let rocketName = launch.rocket?.name {
            Text(rocketName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(Constants.metadataLineLimit)
        }
    }

    @ViewBuilder
    private var launchPadView: some View {
        if let padName = launch.launchPad?.name {
            Label(padName, systemImage: Constants.Icon.launchPad)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(Constants.metadataLineLimit)
        }
    }

    private var launchDateView: some View {
        Label(launch.windowStart.formatted(Constants.windowDateStyle), systemImage: UIConstants.Icon.calendar)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Constants

private enum Constants {
    static let metadataLineLimit = 1

    enum Icon {
        static let launchPad = "mappin.and.ellipse"
    }

    static let windowDateStyle = Date.FormatStyle()
        .month().day().year().hour().minute()
}

// MARK: - Previews

#Preview("Loaded") {
    LaunchCardView(launch: LaunchPreviewFixtures.launch)
        .padding()
}

//
//  LaunchListView.swift
//  TMinus
//
//  Created by Sadegh on 06/05/2026.
//

import SwiftUI

// MARK: - LaunchListView

struct LaunchListView: View {
    @Bindable var viewModel: LaunchListViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                Group {
                    if viewModel.isLoading, viewModel.launches.isEmpty {
                        ProgressView(L10n.Launches.loading)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let errorMessage = viewModel.errorMessage, viewModel.launches.isEmpty {
                        ContentUnavailableView(
                            L10n.Launches.errorTitle,
                            systemImage: "wifi.exclamationmark",
                            description: Text(errorMessage))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.launches.isEmpty {
                        ContentUnavailableView(
                            L10n.Launches.emptyTitle,
                            systemImage: "moon.stars.fill",
                            description: Text(L10n.Launches.emptyDescription))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            VStack(spacing: 16) {
                                Picker(L10n.Launches.modePicker, selection: $viewModel.mode) {
                                    ForEach(LaunchListViewModel.Mode.allCases) { mode in
                                        Text(mode.title).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)

                                ForEach(viewModel.launches) { launch in
                                    LaunchCardView(launch: launch)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .refreshable {
                            await viewModel.load()
                        }
                    }
                }
            }
            .navigationTitle(L10n.Launches.navigationTitle)
            .navigationBarTitleDisplayMode(.large)
            .task(id: viewModel.mode) {
                await viewModel.load()
            }
        }
    }
}

// MARK: - LaunchCardView

private struct LaunchCardView: View {
    let launch: Launch

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
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
                        .fill(Color.secondary.opacity(0.1))
                @unknown default:
                    placeholderImage
                }
            }
            .frame(width: 84, height: 84)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Text(launch.name)
                        .font(.headline)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    StatusPill(status: launch.status)
                }

                Text(launch.rocket.name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Label(launch.launchPad.name, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Label(Self.dateFormatter.string(from: launch.windowStart), systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground)))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1))
    }

    private var placeholderImage: some View {
        ZStack {
            Rectangle()
                .fill(Color.secondary.opacity(0.1))
            Image(systemName: "photo")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - StatusPill

private struct StatusPill: View {
    let status: LaunchStatus

    var body: some View {
        Text(status.label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(status.color.opacity(0.16))
            .foregroundStyle(status.color)
            .clipShape(Capsule())
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

extension LaunchStatus {
    fileprivate var label: String {
        switch self {
        case .go:
            L10n.Launches.Status.go
        case .toBeDetermined:
            L10n.Launches.Status.tbd
        case .hold:
            L10n.Launches.Status.hold
        case .success:
            L10n.Launches.Status.success
        case .failure:
            L10n.Launches.Status.failure
        case let .unknown(value):
            value?.isEmpty == false ? value! : L10n.Launches.Status.unknown
        }
    }

    fileprivate var color: Color {
        switch self {
        case .go, .success:
            .green
        case .toBeDetermined:
            .orange
        case .hold:
            .yellow
        case .failure:
            .red
        case .unknown:
            .gray
        }
    }
}

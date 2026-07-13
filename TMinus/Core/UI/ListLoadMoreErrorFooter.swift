//
//  ListLoadMoreErrorFooter.swift
//  TMinus
//
//  Created by Sadegh on 11/07/2026.
//

import SwiftUI

/// Footer for a failed pagination (load-more) request. Shared by any list screen instead of
/// each feature reimplementing the same message + retry layout.
struct ListLoadMoreErrorFooter: View {
    let message: String
    let retryTitle: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: UIConstants.Spacing.small) {
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: onRetry) {
                Label(retryTitle, systemImage: Constants.Icon.retry)
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, UIConstants.Padding.vertical)
    }
}

// MARK: - Constants

extension ListLoadMoreErrorFooter {
    private enum Constants {
        enum Icon {
            static let retry = "arrow.clockwise"
        }
    }
}

// MARK: - Previews

#Preview {
    ListLoadMoreErrorFooter(message: "Could not load more results.", retryTitle: "Retry", onRetry: {})
        .padding()
}

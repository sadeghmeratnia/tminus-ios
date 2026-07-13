//
//  ListRefreshErrorBanner.swift
//  TMinus
//
//  Created by Sadegh on 11/07/2026.
//

import SwiftUI

/// Inline banner for a failed refresh that still has stale items on screen. Shared by any list
/// screen instead of each feature reimplementing the same message + retry layout.
struct ListRefreshErrorBanner: View {
    let message: String
    let retryTitle: String
    let onRetry: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: UIConstants.Spacing.small) {
            Image(systemName: UIConstants.Icon.networkError)
                .foregroundStyle(.orange)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)

            Spacer(minLength: UIConstants.Spacing.small)

            Button(retryTitle, action: onRetry)
                .font(.caption.weight(.medium))
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(UIConstants.Padding.card)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: UIConstants.CornerRadius.card, style: .continuous)
                .fill(Color.orange.opacity(UIConstants.Opacity.subtleBackground)))
    }
}

// MARK: - Previews

#Preview {
    ListRefreshErrorBanner(message: "Could not refresh. Showing saved results.", retryTitle: "Retry", onRetry: {})
        .padding()
}

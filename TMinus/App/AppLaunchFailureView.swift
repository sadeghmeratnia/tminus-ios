//
//  AppLaunchFailureView.swift
//  TMinus
//
//  Created by Sadegh on 23/07/2026.
//

import SwiftUI

// MARK: - AppLaunchFailureView

/// Shown in place of the app's root view when bootstrap (building the local `ModelContainer`)
/// fails even after `TMinusApp`'s reset-and-retry fallback, so a persistent local-storage
/// failure (full disk, sandbox/permissions issue) degrades to a recoverable screen instead of
/// crashing the app on every launch.
struct AppLaunchFailureView: View {
    let onRetry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(L10n.AppLaunch.title, systemImage: UIConstants.Icon.storageError)
        } description: {
            Text(L10n.AppLaunch.description)
        } actions: {
            Button(L10n.AppLaunch.retryAction, action: onRetry)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier(Constants.AccessibilityID.retryButton)
        }
    }
}

// MARK: - Constants

private extension AppLaunchFailureView {
    enum Constants {
        enum AccessibilityID {
            static let retryButton = "appLaunchFailureRetryButton"
        }
    }
}

// MARK: - Previews

#Preview {
    AppLaunchFailureView(onRetry: {})
}

//
//  StatusPill.swift
//  TMinus
//
//  Created by Sadegh on 07/05/2026.
//

import SwiftUI

// MARK: - StatusPill

struct StatusPill: View {
    let status: LaunchStatus

    var body: some View {
        Text(status.label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, UIConstants.Padding.pillHorizontal)
            .padding(.vertical, UIConstants.Padding.pillVertical)
            .background(status.color.opacity(UIConstants.Opacity.statusBackground))
            .foregroundStyle(status.color)
            .clipShape(Capsule())
            // Self-describing regardless of where this is placed, the plain visible text (e.g.
            // "Go", "Hold") reads as a bare, context-free word to VoiceOver otherwise. Wherever
            // a container already establishes the context via `.accessibilityElement(children:
            // .combine)` (e.g. `LaunchCardView`), this label still combines in cleanly.
            .accessibilityLabel("\(L10n.Launches.Status.accessibilityLabelPrefix): \(status.label)")
    }
}

private extension LaunchStatus {
    var label: String {
        switch self {
        case .go:
            return L10n.Launches.Status.go
        case .toBeDetermined:
            return L10n.Launches.Status.tbd
        case .hold:
            return L10n.Launches.Status.hold
        case .success:
            return L10n.Launches.Status.success
        case .failure:
            return L10n.Launches.Status.failure
        case .unknown:
            // Always the localized fallback, never the raw API value: unlike a missing name
            // (which the API just omits), an unrecognized status string is untranslated,
            // developer-facing content, showing it verbatim would bypass localization for
            // exactly the one case that most needs it, since it's the one status the API
            // controls the wording of unpredictably.
            return L10n.Launches.Status.unknown
        }
    }

    var color: Color {
        switch self {
        case .go, .success:
            return UIConstants.Color.Status.go
        case .toBeDetermined:
            return UIConstants.Color.Status.toBeDetermined
        case .hold:
            return UIConstants.Color.Status.hold
        case .failure:
            return UIConstants.Color.Status.failure
        case .unknown:
            return UIConstants.Color.Status.unknown
        }
    }
}

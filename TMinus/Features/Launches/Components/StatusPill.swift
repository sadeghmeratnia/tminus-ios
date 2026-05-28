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
    }
}

extension LaunchStatus {
    fileprivate var label: String {
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
        case let .unknown(value):
            return (value?.isEmpty == false ? value : nil) ?? L10n.Launches.Status.unknown
        }
    }

    fileprivate var color: Color {
        switch self {
        case .go, .success:
            return .green
        case .toBeDetermined:
            return .orange
        case .hold:
            return .yellow
        case .failure:
            return .red
        case .unknown:
            return .gray
        }
    }
}

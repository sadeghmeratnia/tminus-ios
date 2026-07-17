//
//  UIConstants.swift
//  TMinus
//
//  Created by Sadegh on 07/05/2026.
//

import CoreGraphics
import Foundation
import SwiftUI

enum UIConstants {
    enum Spacing {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
    }

    enum Padding {
        static let horizontal: CGFloat = 16
        static let vertical: CGFloat = 12
        static let card: CGFloat = 14
        static let pillHorizontal: CGFloat = 10
        static let pillVertical: CGFloat = 5
    }

    enum CornerRadius {
        static let image: CGFloat = 12
        static let card: CGFloat = 16
    }

    enum Border {
        static let lineWidth: CGFloat = 1
        static let opacity: CGFloat = 0.06
    }

    enum Opacity {
        static let subtleBackground: CGFloat = 0.1
        static let statusBackground: CGFloat = 0.16
    }

    enum Icon {
        /// SF Symbol for "no network" — used wherever a screen shows a connectivity failure,
        /// so every feature's error state reads as the same failure rather than a per-feature choice.
        static let networkError = "wifi.exclamationmark"
        /// Retry affordance, identical everywhere a failed request offers a retry action.
        static let retry = "arrow.clockwise"
        /// Date metadata, identical everywhere a card or detail screen shows a timestamp.
        static let calendar = "calendar"
        /// Fallback for a thumbnail/hero image that failed to load or hasn't loaded yet.
        static let photoPlaceholder = "photo"
    }

    enum Color {
        /// Non-fatal advisory tint (e.g. "showing saved results after a failed refresh") —
        /// distinct from `.red`/system error tinting, which this app reserves for fatal states.
        /// `.secondary`/`.primary` text colors are intentionally NOT tokenized here: they're
        /// already the correct system-semantic abstraction, used identically across every screen.
        static let warning = SwiftUI.Color.orange
    }
}

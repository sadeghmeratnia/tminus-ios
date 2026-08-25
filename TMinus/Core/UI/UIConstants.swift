//
//  UIConstants.swift
//  TMinus
//
//  Created by Sadegh on 07/05/2026.
//

import CoreGraphics
import Foundation
import SwiftUI
import UIKit

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

    enum Layout {
        /// Shared by every list card's thumbnail (`MediaCardView`), previously duplicated as an
        /// identical private constant in both `LaunchCardView` and `NewsCardView`.
        static let thumbnailSize: CGFloat = 84
        /// Shared by every detail screen's hero image, previously duplicated as an identical
        /// private constant in both `LaunchDetailView` and `NewsDetailView`.
        static let heroHeight: CGFloat = 220
        /// Shared by every list card's title, previously duplicated identically; per-card
        /// metadata line limits still vary by feature and stay local to each card view.
        static let titleLineLimit = 2
    }

    enum Opacity {
        static let subtleBackground: CGFloat = 0.1
        static let statusBackground: CGFloat = 0.16
    }

    enum Icon {
        /// SF Symbol for "no network", used wherever a screen shows a connectivity failure,
        /// so every feature's error state reads as the same failure rather than a per-feature choice.
        static let networkError = "wifi.exclamationmark"
        /// Retry affordance, identical everywhere a failed request offers a retry action.
        static let retry = "arrow.clockwise"
        /// Date metadata, identical everywhere a card or detail screen shows a timestamp.
        static let calendar = "calendar"
        /// Fallback for a thumbnail/hero image that failed to load or hasn't loaded yet.
        static let photoPlaceholder = "photo"
        /// Local storage/bootstrap failure, distinct from `networkError`, since this means the
        /// app couldn't start at all rather than a single request failing.
        static let storageError = "externaldrive.badge.exclamationmark"
        /// `AppRootView`'s Launches tab icon.
        static let launchesTab = "airplane.departure"
        /// `AppRootView`'s News tab icon.
        static let newsTab = "newspaper"
    }

    enum Color {
        /// Non-fatal advisory tint (e.g. "showing saved results after a failed refresh"),
        /// distinct from `.red`/system error tinting, which this app reserves for fatal states.
        /// `.secondary`/`.primary` text colors are intentionally NOT tokenized here: they're
        /// already the correct system-semantic abstraction, used identically across every screen.
        static let warning = SwiftUI.Color.orange

        /// Semantic colors for a launch's status, single-sourced here (rather than living only
        /// inside `StatusPill`) so any future screen that needs the same "go = green" mapping
        /// (e.g. a dashboard summary) reuses it instead of redefining it.
        enum Status {
            static let go = SwiftUI.Color.green
            static let toBeDetermined = SwiftUI.Color.orange
            /// A hand-tuned amber rather than the system `.yellow`, `StatusPill` uses this same
            /// color for both the pill's text and its tinted background fill, and system yellow at
            /// full opacity fails WCAG AA contrast as foreground text on a light background. Unlike
            /// every other case in this enum, this one used to be a single fixed RGB literal,
            /// unlike `.green`/`.orange`/`.red`/`.gray`, which are dynamic system colors, a literal
            /// can't respond to Dark Mode or to Settings → Accessibility → Increase Contrast. Built
            /// via `UIColor(dynamicProvider:)` instead, with a distinct dark-mode shade (brighter,
            /// so it still reads as "caution" against a dark background instead of going muddy) and
            /// a higher-contrast variant for both appearances.
            static let hold = SwiftUI.Color(UIColor { traits in
                let highContrast = traits.accessibilityContrast == .high
                switch traits.userInterfaceStyle {
                case .dark:
                    return highContrast
                        ? UIColor(red: 1.00, green: 0.86, blue: 0.45, alpha: 1)
                        : UIColor(red: 0.98, green: 0.78, blue: 0.30, alpha: 1)
                default:
                    return highContrast
                        ? UIColor(red: 0.48, green: 0.33, blue: 0.00, alpha: 1)
                        : UIColor(red: 0.62, green: 0.44, blue: 0.02, alpha: 1)
                }
            })
            static let failure = SwiftUI.Color.red
            static let unknown = SwiftUI.Color.gray
        }
    }
}

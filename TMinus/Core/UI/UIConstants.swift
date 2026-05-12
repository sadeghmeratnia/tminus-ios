//
//  UIConstants.swift
//  TMinus
//
//  Created by Sadegh on 07/05/2026.
//

import Foundation
import CoreGraphics

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
}

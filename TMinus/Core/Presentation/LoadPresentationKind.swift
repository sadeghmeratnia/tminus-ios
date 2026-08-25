//
//  LoadPresentationKind.swift
//  TMinus
//
//  Created by Sadegh on 23/07/2026.
//

import Foundation

// MARK: - LoadPresentationKind

/// Tells the UI whether a load failure should replace the screen or appear above existing content.
enum LoadPresentationKind: Equatable, Sendable {
    case initial
    case refresh
}

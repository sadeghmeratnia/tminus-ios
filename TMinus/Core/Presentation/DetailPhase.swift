//
//  DetailPhase.swift
//  TMinus
//
//  Created by Sadegh on 01/07/2026.
//

import Foundation

// MARK: - DetailPhase

/// The loading phase for any single-item detail screen (e.g. `LaunchDetailState`, `NewsDetailState`).
/// Shared across features so every detail screen models idle/loading/loaded/error identically,
/// new features should reuse this rather than defining a feature-specific phase enum.
enum DetailPhase: Equatable {
    case idle
    case loading
    case loaded
    case error(message: String)
}

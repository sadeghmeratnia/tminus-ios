//
//  FetchPolicy.swift
//  TMinus
//
//  Created by Sadegh on 01/07/2026.
//

import Foundation

// MARK: - FetchPolicy

/// Chooses whether this request may use a fresh cached response or must hit the network.
/// The endpoint still decides whether its responses are cacheable and for how long.
enum FetchPolicy: Equatable, Sendable {
    /// Return cached data if available and fresh; fall back to the network.
    case useCache
    /// Always go to the network, bypassing any cached response.
    case networkOnly
}

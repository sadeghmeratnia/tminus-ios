//
//  FetchPolicy.swift
//  TMinus
//
//  Created by Sadegh on 01/07/2026.
//

import Foundation

// MARK: - FetchPolicy

/// Controls whether a request may be served from cache or must go to the network. Used at every
/// layer — domain (`*ListQuery.fetchPolicy`), data (repositories), and networking
/// (`NetworkClientProtocol`) — with no conversion between layers, so any feature's list or
/// detail flow can express "cache first" vs. "force refresh" the same way.
enum FetchPolicy: Equatable {
    /// Return cached data if available and fresh; fall back to the network.
    case useCache
    /// Always go to the network, bypassing any cached response.
    case networkOnly
}

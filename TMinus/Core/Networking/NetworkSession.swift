//
//  NetworkSession.swift
//  TMinus
//
//  Created by Sadegh on 05/05/2026.
//

import Foundation

// MARK: - NetworkSession

protocol NetworkSession: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

// MARK: - URLSession + NetworkSession

extension URLSession: NetworkSession {}

extension URLSession {
    /// The `URLSession` this app's `URLSessionNetworkClient` should be built on, `URLSession
    /// .shared` deliberately isn't used, since its default configuration has a live `URLCache`
    /// that would keep writing every response to disk/memory in parallel with the app's own
    /// `DataCache`. `Endpoint.urlRequest()` already sets `.reloadIgnoringLocalCacheData` so
    /// `URLCache` is never *read* from, but that alone doesn't stop it from *storing* responses;
    /// disabling the cache at the session level is what actually makes `DataCache` the only
    /// cache layer instead of two uncoordinated ones.
    static let appNetworking: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }()
}

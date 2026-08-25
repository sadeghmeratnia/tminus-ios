//
//  ImageDataLoader.swift
//  TMinus
//
//  Created by Sadegh on 16/08/2026.
//

import Foundation

// MARK: - ImageDataLoading

protocol ImageDataLoading: Sendable {
    func data(for url: URL) async throws -> Data
}

// MARK: - NetworkImageDataLoader

/// Routes remote-image fetches through the same `NetworkClientProtocol` (and therefore the same
/// `DataCache`, retry policy, and logging) as every other network call in the app, instead of
/// letting images quietly fetch through a second, uncoordinated cache/session, see
/// `RemoteImagePhaseView` for the failure mode this closes.
struct NetworkImageDataLoader: ImageDataLoading {
    private let networkClient: NetworkClientProtocol

    init(networkClient: NetworkClientProtocol) {
        self.networkClient = networkClient
    }

    func data(for url: URL) async throws -> Data {
        // The image URL is already complete, so it's passed as `baseURL` with an empty `path`
        // rather than split apart and reassembled.
        let endpoint = Endpoint(baseURL: url, path: "", cacheTTL: Constants.cacheTTL)
        return try await networkClient.requestData(endpoint: endpoint)
    }
}

private extension NetworkImageDataLoader {
    enum Constants {
        /// Unlike list/detail JSON, a given image URL's bytes don't change once served, a
        /// changed photo gets a new URL. Caching far longer than the default response TTL avoids
        /// re-fetching the same thumbnail every time its cache entry ages out.
        ///
        /// This assumes image URLs themselves are stable, not signed/expiring (no rotating
        /// `?token=`/`?expires=` query parameters), `URLSessionNetworkClient`'s cache key folds
        /// in the full query string, so a signed URL that changes on every fetch for what's
        /// logically the same image would defeat this TTL entirely, with every "cache hit"
        /// opportunity lost to URL churn. Both APIs this app talks to (Launch Library 2,
        /// Spaceflight News) currently return plain, unsigned image URLs.
        static let cacheTTL: TimeInterval = 60 * 60 * 24
    }
}

//
//  CachedFetchCoordinator.swift
//  TMinus
//

import Foundation

// MARK: - CachedFetchCoordinator

/// Handles the shared cache, network and persistence flow for repository list requests.
/// Detail requests stay in their repositories because their cache and error handling differ.
enum CachedFetchCoordinator {
    static func fetch<Item: Sendable, Wrapped: Sendable>(
        fetchPolicy: FetchPolicy,
        maxAge: TimeInterval,
        local: (_ maxAge: TimeInterval?) async throws -> [Item],
        // Distinguishes an empty cache from a fresh cache where the active filter matched nothing.
        localHasFreshDataIgnoringFilter: ((_ maxAge: TimeInterval?) async throws -> Bool)? = nil,
        wrap: ([Item]) -> Wrapped,
        remote: () async throws -> Wrapped,
        persist: (Wrapped) async throws -> Void,
        onLocalReadFailure: (Error) -> Void,
        onPersistFailure: (Error) -> Void
    ) async throws -> Wrapped {
        if fetchPolicy == .useCache {
            do {
                let cached = try await local(maxAge)
                if cached.isEmpty == false {
                    return wrap(cached)
                }
                if let localHasFreshDataIgnoringFilter, try await localHasFreshDataIgnoringFilter(maxAge) {
                    // The cache is fresh. The filter simply has no matches.
                    return wrap(cached)
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // Treat a failed initial cache read like a miss and continue to the network.
                onLocalReadFailure(error)
            }
        }

        let result: Wrapped
        do {
            result = try await remote()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // A stale non-empty cache can soften a network failure. An empty stale cache cannot
            // prove there are no results, so keep the original network error in that case.
            if fetchPolicy == .useCache, let stale = try? await local(nil), stale.isEmpty == false {
                return wrap(stale)
            }
            throw NetworkFeatureError.map(error)
        }

        // A cache write failure should not discard a successful network response.
        do {
            try await persist(result)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            onPersistFailure(error)
        }
        return result
    }
}

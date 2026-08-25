//
//  LaunchRepository.swift
//  TMinus
//
//  Created by Sadegh on 06/05/2026.
//

import Foundation
import OSLog

// MARK: - LaunchRepository

/// Uses SwiftData as the primary cache and the network client's byte cache as a fallback.
/// Cached results are refreshed only by an explicit `.networkOnly` request.
final class LaunchRepository: LaunchRepositoryProtocol, Sendable {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "app",
        category: "LaunchRepository"
    )

    private let remoteDataSource: LaunchRemoteDataSource
    private let localDataSource: LaunchLocalDataSource
    /// Keeps a slow, older request from overwriting a newer page. Each list has its own sequence.
    private let upcomingPersistSequencer = PersistSequencer()
    private let previousPersistSequencer = PersistSequencer()

    init(remoteDataSource: LaunchRemoteDataSource,
         localDataSource: LaunchLocalDataSource)
    {
        self.remoteDataSource = remoteDataSource
        self.localDataSource = localDataSource
    }

    func fetchUpcomingLaunches(query: LaunchListQuery) async throws -> PagedResult<Launch> {
        let ticket = await upcomingPersistSequencer.startingFetch()
        return try await CachedFetchCoordinator.fetch(
            fetchPolicy: query.fetchPolicy,
            maxAge: LaunchCacheTTL.upcoming,
            local: { try await self.localDataSource.fetchUpcomingLaunches(query: query, maxAge: $0) },
            localHasFreshDataIgnoringFilter: Self.hasFreshDataIgnoringSearch(query: query) { unfiltered, maxAge in
                try await self.localDataSource.fetchUpcomingLaunches(query: unfiltered, maxAge: maxAge)
            },
            wrap: { PagedResult.fromCachePage(items: $0, page: query.page) },
            remote: {
                let response = try await self.remoteDataSource.fetchUpcomingLaunches(query: query)
                return Self.mapPage(response, query: query)
            },
            persist: { page in
                guard await self.upcomingPersistSequencer.shouldPersist(ticket: ticket) else { return }
                try await self.localDataSource.save(page.items, fetchedAt: Date())
            },
            onLocalReadFailure: {
                Self.logger.error("Failed to read cached upcoming launches: \(String(describing: $0), privacy: .public)")
            },
            onPersistFailure: {
                Self.logger.error("Failed to persist launch page: \(String(describing: $0), privacy: .public)")
            }
        )
    }

    func fetchPreviousLaunches(query: LaunchListQuery) async throws -> PagedResult<Launch> {
        let ticket = await previousPersistSequencer.startingFetch()
        return try await CachedFetchCoordinator.fetch(
            fetchPolicy: query.fetchPolicy,
            maxAge: LaunchCacheTTL.previous,
            local: { try await self.localDataSource.fetchPreviousLaunches(query: query, maxAge: $0) },
            localHasFreshDataIgnoringFilter: Self.hasFreshDataIgnoringSearch(query: query) { unfiltered, maxAge in
                try await self.localDataSource.fetchPreviousLaunches(query: unfiltered, maxAge: maxAge)
            },
            wrap: { PagedResult.fromCachePage(items: $0, page: query.page) },
            remote: {
                let response = try await self.remoteDataSource.fetchPreviousLaunches(query: query)
                return Self.mapPage(response, query: query)
            },
            persist: { page in
                guard await self.previousPersistSequencer.shouldPersist(ticket: ticket) else { return }
                try await self.localDataSource.save(page.items, fetchedAt: Date())
            },
            onLocalReadFailure: {
                Self.logger.error("Failed to read cached previous launches: \(String(describing: $0), privacy: .public)")
            },
            onPersistFailure: {
                Self.logger.error("Failed to persist launch page: \(String(describing: $0), privacy: .public)")
            }
        )
    }

    func fetchLaunchDetail(id: String, fetchPolicy: FetchPolicy) async throws -> Launch {
        if fetchPolicy == .useCache {
            do {
                if let cached = try await localDataSource.fetchLaunchDetail(id: id, maxAge: LaunchCacheTTL.detail) {
                    return cached
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // A failed initial cache read is equivalent to a miss, so continue to the network.
                Self.logger.error(
                    "Failed to read cached launch detail \(id, privacy: .public): \(String(describing: error), privacy: .public)"
                )
            }
        }

        let launch: Launch
        do {
            let dto = try await remoteDataSource.fetchLaunchDetail(id: id, fetchPolicy: fetchPolicy)
            launch = LaunchDTOMapper.map(dto)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // Cache-enabled loads may fall back to a stale row. Forced refreshes should report
            // the network failure so the UI can show its refresh error.
            if fetchPolicy == .useCache,
               let stale = try? await localDataSource.fetchLaunchDetail(id: id, maxAge: nil)
            {
                return stale
            }
            // Preserve errors that have already been mapped to the feature-level type.
            throw (error as? NetworkFeatureError) ?? NetworkFeatureError.map(error)
        }

        // Do not discard a successful response just because its cache write failed.
        do {
            try await localDataSource.save(launch, fetchedAt: Date())
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            Self.logger.error(
                "Failed to persist launch detail \(id, privacy: .public): \(String(describing: error), privacy: .public)"
            )
        }
        return launch
    }
}

private extension LaunchRepository {
    static func mapPage(_ response: LaunchesResponseDTO, query: LaunchListQuery) -> PagedResult<Launch> {
        PagedResult(
            items: response.results.map(LaunchDTOMapper.map(_:)),
            currentPage: query.page,
            totalCount: response.count,
            nextPage: PaginationURLParser.pageNumber(from: response.next, fallbackLimit: query.limit),
            previousPage: PaginationURLParser.pageNumber(from: response.previous, fallbackLimit: query.limit)
        )
    }

    /// Checks whether an empty search result came from a fresh, populated cache.
    static func hasFreshDataIgnoringSearch(
        query: LaunchListQuery,
        fetch: @escaping (_ unfiltered: LaunchListQuery, _ maxAge: TimeInterval?) async throws -> [Launch]
    ) -> ((_ maxAge: TimeInterval?) async throws -> Bool)? {
        guard let searchText = query.searchText, searchText.isEmpty == false else { return nil }
        let unfiltered = LaunchListQuery(page: query.page, limit: query.limit, searchText: nil, fetchPolicy: query.fetchPolicy)
        return { maxAge in
            try await fetch(unfiltered, maxAge).isEmpty == false
        }
    }
}

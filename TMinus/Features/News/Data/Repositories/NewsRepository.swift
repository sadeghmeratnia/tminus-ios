//
//  NewsRepository.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import Foundation
import OSLog

// MARK: - NewsRepository

/// See `LaunchRepository`'s doc comment for the full rationale shared by both features: how this
/// repository's `localDataSource` cache relates to `URLSessionNetworkClient`'s `DataCache`
/// underneath it, and why a `.useCache` hit never triggers a background refresh.
final class NewsRepository: NewsRepositoryProtocol, Sendable {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "app",
        category: "NewsRepository"
    )

    private let remoteDataSource: NewsRemoteDataSource
    private let localDataSource: NewsLocalDataSource
    /// See `LaunchRepository`'s equivalent, guards against a slower-resolving fetch (e.g. an
    /// auto-triggered `.useCache` load) clobbering a faster, later-issued one's already-persisted
    /// page (e.g. a user-initiated pull-to-refresh racing it).
    private let articlesPersistSequencer = PersistSequencer()

    init(remoteDataSource: NewsRemoteDataSource, localDataSource: NewsLocalDataSource) {
        self.remoteDataSource = remoteDataSource
        self.localDataSource = localDataSource
    }

    func fetchArticles(query: NewsListQuery) async throws -> PagedResult<NewsArticle> {
        let ticket = await articlesPersistSequencer.startingFetch()
        return try await CachedFetchCoordinator.fetch(
            fetchPolicy: query.fetchPolicy,
            maxAge: NewsCacheTTL.list,
            local: { try await self.localDataSource.fetchArticles(query: query, maxAge: $0) },
            localHasFreshDataIgnoringFilter: Self.hasFreshDataIgnoringSearch(query: query) { unfiltered, maxAge in
                try await self.localDataSource.fetchArticles(query: unfiltered, maxAge: maxAge)
            },
            wrap: { PagedResult.fromCachePage(items: $0, page: query.page) },
            remote: {
                let response = try await self.remoteDataSource.fetchArticles(query: query)
                return Self.mapPage(response, query: query)
            },
            persist: { page in
                guard await self.articlesPersistSequencer.shouldPersist(ticket: ticket) else { return }
                try await self.localDataSource.save(page.items, fetchedAt: Date())
            },
            onLocalReadFailure: {
                Self.logger.error("Failed to read cached news articles: \(String(describing: $0), privacy: .public)")
            },
            onPersistFailure: {
                Self.logger.error("Failed to persist news article page: \(String(describing: $0), privacy: .public)")
            }
        )
    }

    func fetchArticleDetail(id: String, fetchPolicy: FetchPolicy) async throws -> NewsArticle {
        if fetchPolicy == .useCache {
            do {
                if let cached = try await localDataSource.fetchArticleDetail(id: id, maxAge: NewsCacheTTL.detail) {
                    return cached
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // As in `CachedFetchCoordinator`: a failing *initial* cache read must not abort
                // the whole fetch, it's no worse than a cache miss, so this falls through to the
                // remote fetch below instead of surfacing a persistence error as if it were a
                // network one.
                Self.logger.error(
                    "Failed to read cached news article \(id, privacy: .public): \(String(describing: error), privacy: .public)"
                )
            }
        }

        let article: NewsArticle
        do {
            let dto = try await remoteDataSource.fetchArticleDetail(id: id, fetchPolicy: fetchPolicy)
            guard let mapped = NewsArticleDTOMapper.map(dto) else {
                throw NetworkFeatureError.decodingFailed
            }
            article = mapped
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // Falls back to stale cache for *any* failure, a transport error, a server error, or
            // the `.decodingFailed` thrown above for an unmappable article, when the caller
            // allows cache use. Previously `.decodingFailed` short-circuited straight past this
            // fallback via its own catch clause, so a malformed-but-otherwise-fine response could
            // hard-fail the screen even with a perfectly good stale article sitting in the cache.
            // Only consulted when `fetchPolicy == .useCache`, a `.networkOnly` refresh must
            // reflect real network state instead of silently re-serving old data. See
            // `LaunchRepository.fetchLaunchDetail` for the identical rationale (and the bug this
            // guard specifically prevents: without it, every failed refresh after a first
            // successful load would silently look like it succeeded).
            if fetchPolicy == .useCache,
               let stale = try? await localDataSource.fetchArticleDetail(id: id, maxAge: nil)
            {
                return stale
            }
            // `error` may already be a `NetworkFeatureError` (e.g. `.decodingFailed` thrown just
            // above), `NetworkFeatureError.map` only classifies plain `NetworkError`/unknown
            // errors, so re-running an already-typed one through it would misclassify it as
            // `.unknown` instead of preserving its real case.
            throw (error as? NetworkFeatureError) ?? NetworkFeatureError.map(error)
        }

        // The fetch already succeeded, a persistence failure here must not discard the
        // in-hand article or be mistaken for a network error by the caller. Best-effort cache
        // write only; log and move on.
        do {
            try await localDataSource.save(article, fetchedAt: Date())
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            Self.logger.error(
                "Failed to persist news article \(id, privacy: .public): \(String(describing: error), privacy: .public)"
            )
        }
        return article
    }

    func fetchRelatedArticles(launchID: String, limit: Int, fetchPolicy: FetchPolicy) async throws -> [NewsArticle] {
        try await CachedFetchCoordinator.fetch(
            fetchPolicy: fetchPolicy,
            maxAge: NewsCacheTTL.related,
            local: { try await self.localDataSource.fetchRelatedArticles(launchID: launchID, limit: limit, maxAge: $0) },
            wrap: { $0 },
            remote: {
                let response = try await self.remoteDataSource.fetchRelatedArticles(
                    launchID: launchID,
                    limit: limit,
                    fetchPolicy: fetchPolicy
                )
                return response.results.compactMap(NewsArticleDTOMapper.map(_:))
            },
            persist: { try await self.localDataSource.save($0, fetchedAt: Date()) },
            onLocalReadFailure: {
                Self.logger.error("Failed to read cached related news articles: \(String(describing: $0), privacy: .public)")
            },
            onPersistFailure: {
                Self.logger.error("Failed to persist related news articles: \(String(describing: $0), privacy: .public)")
            }
        )
    }
}

private extension NewsRepository {
    static func mapPage(_ response: NewsResponseDTO, query: NewsListQuery) -> PagedResult<NewsArticle> {
        PagedResult(
            items: response.results.compactMap(NewsArticleDTOMapper.map(_:)),
            currentPage: query.page,
            totalCount: response.count,
            nextPage: PaginationURLParser.pageNumber(from: response.next, fallbackLimit: query.limit),
            previousPage: PaginationURLParser.pageNumber(from: response.previous, fallbackLimit: query.limit)
        )
    }

    /// See `LaunchRepository.hasFreshDataIgnoringSearch`, identical rationale, mirrored here for
    /// `NewsListQuery`/`NewsArticle`.
    static func hasFreshDataIgnoringSearch(
        query: NewsListQuery,
        fetch: @escaping (_ unfiltered: NewsListQuery, _ maxAge: TimeInterval?) async throws -> [NewsArticle]
    ) -> ((_ maxAge: TimeInterval?) async throws -> Bool)? {
        guard let searchText = query.searchText, searchText.isEmpty == false else { return nil }
        let unfiltered = NewsListQuery(page: query.page, limit: query.limit, searchText: nil, fetchPolicy: query.fetchPolicy)
        return { maxAge in
            try await fetch(unfiltered, maxAge).isEmpty == false
        }
    }
}

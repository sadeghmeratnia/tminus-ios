//
//  URLSessionNetworkClient.swift
//  TMinus
//
//  Created by Sadegh on 22/04/2026.
//

import Foundation

// MARK: - URLSessionNetworkClient

final class URLSessionNetworkClient: NetworkClientProtocol, Sendable {
    private let session: NetworkSession
    private let makeDecoder: @Sendable () -> JSONDecoder
    private let retryPolicy: RetryPolicy
    private let logger: NetworkLogger
    private let cache: DataCache

    init(session: NetworkSession,
         decoder: JSONDecoder,
         retryPolicy: RetryPolicy,
         logger: NetworkLogger,
         cache: DataCache)
    {
        self.session = session
        makeDecoder = {
            let configuredDecoder = JSONDecoder()
            configuredDecoder.keyDecodingStrategy = decoder.keyDecodingStrategy
            configuredDecoder.dateDecodingStrategy = decoder.dateDecodingStrategy
            configuredDecoder.dataDecodingStrategy = decoder.dataDecodingStrategy
            configuredDecoder.nonConformingFloatDecodingStrategy = decoder.nonConformingFloatDecodingStrategy
            configuredDecoder.userInfo = decoder.userInfo
            return configuredDecoder
        }
        self.retryPolicy = retryPolicy
        self.logger = logger
        self.cache = cache
    }

    func requestData(endpoint: Endpoint, cachePolicy: FetchPolicy) async throws -> Data {
        let request = try endpoint.urlRequest()
        logger.log("→ \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "")", level: .info)

        // Computed once and reused for both the lookup and the store below, rather than
        // recomputing the same deterministic value (URL parsing + query-item sort) twice.
        let cacheKey = cacheKey(for: request, endpoint: endpoint)

        if cachePolicy == .useCache, let cacheKey {
            if let cachedValue = await cache.cachedValue(for: cacheKey) {
                logger.log(
                    "↻ Cache hit \(cacheKey) source=\(String(describing: cachedValue.metadata.source)) stale=\(cachedValue.metadata.isStale)",
                    level: .debug
                )
                return cachedValue.data
            }
        }

        let data = try await execute(request: request)
        if let cacheKey {
            await cache.set(data, for: cacheKey, ttl: endpoint.cacheTTL, source: .network)
        }
        return data
    }

    func request<T: Decodable & Sendable>(_ type: T.Type, endpoint: Endpoint, cachePolicy: FetchPolicy) async throws -> T {
        let data = try await requestData(endpoint: endpoint, cachePolicy: cachePolicy)
        do {
            return try await decode(type, from: data)
        } catch {
            logger.log("✖ Decoding failed for \(T.self): \(error)", level: .error)
            throw NetworkError.decoding(ErrorSummary(error))
        }
    }

    /// Runs off the caller's actor so JSON decoding never blocks the MainActor.
    @concurrent
    private func decode<T: Decodable & Sendable>(_ type: T.Type, from data: Data) async throws -> T {
        try makeDecoder().decode(type, from: data)
    }

    private func execute(request: URLRequest, attempt: Int = 0) async throws -> Data {
        try Task.checkCancellation()
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            guard (200 ... 299).contains(httpResponse.statusCode) else {
                return try await retryOrThrow(
                    NetworkError.statusCode(httpResponse.statusCode),
                    request: request,
                    attempt: attempt
                )
            }

            logger.log("← \(httpResponse.statusCode)", level: .info)
            return data

        } catch is CancellationError {
            logger.log("ℹ️ Request cancelled", level: .info)
            throw CancellationError()

        } catch let urlError as URLError where urlError.code == .cancelled {
            // URLSession surfaces task cancellation as URLError(.cancelled), not Swift's
            // CancellationError, so it must be rethrown as the latter for callers'
            // `catch is CancellationError` to see it instead of a spurious network error.
            logger.log("ℹ️ Request cancelled", level: .info)
            throw CancellationError()

        } catch let urlError as URLError {
            return try await retryOrThrow(
                NetworkError.transport(urlError),
                request: request,
                attempt: attempt
            )

        } catch let networkError as NetworkError {
            // Rethrown as-is to avoid the generic catch below re-wrapping an already-classified
            // NetworkError (e.g. from the recursive retry call) as `.unknown(underlying:)`.
            throw networkError

        } catch {
            logger.log("✖ Unknown error: \(error)", level: .error)
            throw NetworkError.unknown(underlying: ErrorSummary(error))
        }
    }

    private func retryOrThrow(_ error: NetworkError,
                              request: URLRequest,
                              attempt: Int) async throws -> Data
    {
        if retryPolicy.shouldRetry(error: error, attempt: attempt) {
            logger.log("⚠️ Retrying attempt \(attempt + 1): \(error)", level: .warning)
            try await Task.sleep(nanoseconds: retryPolicy.delay(for: attempt))
            return try await execute(request: request, attempt: attempt + 1)
        }
        logger.log("✖ Non-retryable: \(error)", level: .error)
        throw error
    }

    private func cacheKey(for request: URLRequest, endpoint: Endpoint) -> String? {
        guard endpoint.cacheable,
              request.httpMethod == HTTPMethod.get.rawValue,
              let url = request.url,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return nil }

        // Sort query items so the same logical request always produces the same cache key,
        // regardless of the order they happened to be constructed in.
        components.queryItems = components.queryItems?.sorted {
            $0.name == $1.name ? ($0.value ?? "") < ($1.value ?? "") : $0.name < $1.name
        }

        guard let stableURLString = components.url?.absoluteString else { return nil }
        return "\(HTTPMethod.get.rawValue)|\(stableURLString)"
    }
}

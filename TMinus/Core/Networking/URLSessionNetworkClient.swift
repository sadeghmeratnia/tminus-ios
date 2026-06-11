//
//  URLSessionNetworkClient.swift
//  TMinus
//
//  Created by Sadegh on 22/04/2026.
//

import Foundation

// MARK: - URLSessionNetworkClient

final class URLSessionNetworkClient: NetworkClientProtocol {
    private let session: NetworkSession
    private let makeDecoder: @Sendable () -> JSONDecoder
    private let retryPolicy: RetryPolicy
    private let logger: NetworkLogger
    private let cache: DataCache

    init(session: NetworkSession,
         decoder: JSONDecoder,
         retryPolicy: RetryPolicy,
         logger: NetworkLogger,
         cache: DataCache) {
        self.session = session
        self.makeDecoder = {
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

    func requestData(endpoint: Endpoint, cachePolicy: CachePolicy) async throws -> Data {
        let request = try endpoint.urlRequest()
        logger.log("→ \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "")", level: .info)

        if cachePolicy == .useCache,
           let cacheKey = cacheKey(for: request, endpoint: endpoint) {
            if let cachedValue = await cache.cachedValue(for: cacheKey) {
                logger.log(
                    "↻ Cache hit \(cacheKey) source=\(String(describing: cachedValue.metadata.source)) stale=\(cachedValue.metadata.isStale)",
                    level: .debug)
                return cachedValue.data
            }
        }

        let data = try await execute(request: request)
        if let cacheKey = cacheKey(for: request, endpoint: endpoint) {
            await cache.set(data, for: cacheKey, ttl: endpoint.cacheTTL, source: .network)
        }
        return data
    }

    func request<T: Decodable>(_ type: T.Type, endpoint: Endpoint, cachePolicy: CachePolicy) async throws -> T {
        let data = try await requestData(endpoint: endpoint, cachePolicy: cachePolicy)
        do {
            return try makeDecoder().decode(type, from: data)
        } catch {
            logger.log("✖ Decoding failed for \(T.self): \(error)", level: .error)
            throw NetworkError.decoding(error)
        }
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
                    attempt: attempt)
            }

            logger.log("← \(httpResponse.statusCode)", level: .info)
            return data

        } catch is CancellationError {
            logger.log("ℹ️ Request cancelled", level: .info)
            throw CancellationError()

        } catch let urlError as URLError {
            return try await retryOrThrow(
                NetworkError.transport(urlError),
                request: request,
                attempt: attempt)

        } catch let networkError as NetworkError {
            throw networkError

        } catch {
            logger.log("✖ Unknown error: \(error)", level: .error)
            throw NetworkError.unknown(underlying: error)
        }
    }

    private func retryOrThrow(_ error: NetworkError,
                              request: URLRequest,
                              attempt: Int) async throws -> Data {
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
              let urlString = request.url?.absoluteString
        else { return nil }
        return "\(HTTPMethod.get.rawValue)|\(urlString)"
    }
}

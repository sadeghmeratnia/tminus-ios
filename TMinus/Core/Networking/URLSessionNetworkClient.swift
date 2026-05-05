//
//  URLSessionNetworkClient.swift
//  TMinus
//
//  Created by Sadegh on 22/04/2026.
//

import Foundation

// MARK: - URLSessionNetworkClient

final class URLSessionNetworkClient: NetworkClientProtocol {
    private let baseURL: URL
    private let session: NetworkSession
    private let decoder: JSONDecoder
    private let retryPolicy: RetryPolicy
    private let logger: NetworkLogger

    init(baseURL: URL,
         session: NetworkSession,
         decoder: JSONDecoder,
         retryPolicy: RetryPolicy,
         logger: NetworkLogger) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
        self.retryPolicy = retryPolicy
        self.logger = logger
    }

    func requestData(endpoint: Endpoint) async throws -> Data {
        let request = try endpoint.urlRequest(baseURL: baseURL)
        logger.log("→ \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "")", level: .info)
        return try await execute(request: request)
    }

    func request<T: Decodable>(_ type: T.Type, endpoint: Endpoint) async throws -> T {
        let data = try await requestData(endpoint: endpoint)
        do {
            return try decoder.decode(type, from: data)
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

            guard (200...299).contains(httpResponse.statusCode) else {
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

        } catch let urlError as URLError {
            return try await retryOrThrow(
                NetworkError.transport(urlError),
                request: request,
                attempt: attempt
            )

        } catch let networkError as NetworkError {
            throw networkError

        } catch {
            logger.log("✖ Unknown error: \(error)", level: .error)
            throw NetworkError.unknown(underlying: error)
        }
    }

    private func retryOrThrow(
        _ error: NetworkError,
        request: URLRequest,
        attempt: Int
    ) async throws -> Data {
        if retryPolicy.shouldRetry(error: error, attempt: attempt) {
            logger.log("⚠️ Retrying attempt \(attempt + 1): \(error)", level: .warning)
            try await Task.sleep(nanoseconds: retryPolicy.delay(for: attempt))
            return try await execute(request: request, attempt: attempt + 1)
        }
        logger.log("✖ Non-retryable: \(error)", level: .error)
        throw error
    }
}

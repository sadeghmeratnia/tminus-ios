//
//  URLSessionNetworkClientTests.swift
//  TMinus
//
//  Created by Sadegh on 01/05/2026.
//

import Foundation
import Testing
@testable import TMinus

// MARK: - URLSessionNetworkClientTests

@Suite("URLSessionNetworkClient")
enum URLSessionNetworkClientTests {
    // MARK: - Success

    @Suite("Success")
    struct Success {
        @Test("Returns decoded model on 200")
        func returnsDecodedModelOn200() async throws {
            let expected = MockModel(id: 1, name: "Falcon 9")
            let data = try JSONEncoder().encode(expected)
            let client = make { _ in response(statusCode: 200, data: data) }

            let result = try await client.request(MockModel.self, endpoint: .mock)

            #expect(result == expected)
        }

        @Test("Returns data on 200 for requestData")
        func returnsDataOn200() async throws {
            let expected = Data("hello".utf8)
            let client = make { _ in response(statusCode: 200, data: expected) }

            let result = try await client.requestData(endpoint: .mock)

            #expect(result == expected)
        }

        @Test("Succeeds on all 2xx status codes", arguments: [200, 201, 204, 299])
        func succeedsOn2xx(statusCode: Int) async throws {
            let client = make { _ in response(statusCode: statusCode) }

            await #expect(throws: Never.self) {
                _ = try await client.requestData(endpoint: .mock)
            }
        }
    }

    // MARK: - Status Code Errors

    @Suite("Status Code Errors")
    struct StatusCodeErrors {
        @Test("Throws statusCode error on non-2xx response", arguments: [400, 401, 403, 404, 500])
        func throwsStatusCodeError(statusCode: Int) async {
            let client = make { _ in response(statusCode: statusCode) }

            await assertThrowsStatusCode(statusCode) {
                _ = try await client.requestData(endpoint: .mock)
            }
        }
    }

    // MARK: - Decoding Errors

    @Suite("Decoding Errors")
    struct DecodingErrors {
        @Test("Throws decoding error on invalid JSON")
        func throwsDecodingErrorOnInvalidJSON() async {
            let client = make { _ in
                response(statusCode: 200, data: Data("invalid json".utf8))
            }

            await assertThrowsDecodingError {
                _ = try await client.request(MockModel.self, endpoint: .mock)
            }
        }
    }

    // MARK: - Retry

    @Suite("Retry")
    struct Retry {
        @Test("Retries on 503 and succeeds on second attempt")
        func retriesOn503AndSucceeds() async throws {
            let expected = MockModel(id: 1, name: "Falcon 9")
            let data = try JSONEncoder().encode(expected)
            // `nonisolated(unsafe)` is safe here specifically because `MockNetworkSession`
            // invokes its handler serially, one `await` at a time, within this single test
            // function, never from two tasks concurrently. The Swift 6 compiler can't see that
            // guarantee through the `@Sendable` closure boundary, only this comment can state it.
            nonisolated(unsafe) var attemptCount = 0

            let retryPolicy = retryOnStatusCode(503, maxAttempts: 3)

            let client = make(retryPolicy: retryPolicy) { _ in
                attemptCount += 1
                if attemptCount == 1 {
                    return response(statusCode: 503)
                }
                return response(statusCode: 200, data: data)
            }

            let result = try await client.request(MockModel.self, endpoint: .mock)

            #expect(result == expected)
            #expect(attemptCount == 2)
        }

        @Test("Exhausts retries and throws after max attempts")
        func exhaustsRetriesAndThrows() async {
            // See `retriesOn503AndSucceeds`, same "called serially within this test" rationale.
            nonisolated(unsafe) var attemptCount = 0

            let retryPolicy = retryOnStatusCode(503, maxAttempts: 3)

            let client = make(retryPolicy: retryPolicy) { _ in
                attemptCount += 1
                return response(statusCode: 503)
            }

            await assertThrowsStatusCode(503) {
                _ = try await client.requestData(endpoint: .mock)
            }

            // 1 initial + 3 retries
            #expect(attemptCount == 4)
        }
    }

    // MARK: - Cancellation

    @Suite("Cancellation")
    struct Cancellation {
        @Test("Throws CancellationError when task is already cancelled")
        func throwsCancellationErrorWhenAlreadyCancelled() async throws {
            let client = make { _ in response(statusCode: 200) }

            let task = Task {
                try Task.checkCancellation()
                return try await client.requestData(endpoint: .mock)
            }
            task.cancel()

            await #expect(throws: CancellationError.self) {
                try await task.value
            }
        }
    }

    // MARK: - Invalid Response

    @Suite("Invalid Response")
    struct InvalidResponse {
        @Test("Throws invalidResponse when response is not HTTPURLResponse")
        func throwsInvalidResponse() async {
            let client = make { request in
                nonHTTPResponse(for: request)
            }

            await assertThrowsInvalidResponse {
                _ = try await client.requestData(endpoint: .mock)
            }
        }
    }

    // MARK: - Caching

    @Suite("Caching")
    struct Caching {
        @Test("Returns cached data for repeated GET requests")
        func returnsCachedDataForRepeatedGETRequests() async throws {
            let expected = Data("cached-response".utf8)
            // See `retriesOn503AndSucceeds`, same "called serially within this test" rationale.
            nonisolated(unsafe) var requestCount = 0
            let cache = DataCache(ttl: 60)

            let client = make(cache: cache) { _ in
                requestCount += 1
                return response(statusCode: 200, data: expected)
            }

            let first = try await client.requestData(endpoint: .mock)
            let second = try await client.requestData(endpoint: .mock)

            #expect(first == expected)
            #expect(second == expected)
            #expect(requestCount == 1)
        }

        @Test("Does not use cache for non-GET requests")
        func doesNotUseCacheForNonGETRequests() async throws {
            let expected = Data("post-response".utf8)
            // See `retriesOn503AndSucceeds`, same "called serially within this test" rationale.
            nonisolated(unsafe) var requestCount = 0
            let cache = DataCache(ttl: 60)
            let endpoint = try Endpoint(baseURL: #require(URL(string: "https://example.com")), path: "mock-post", method: .post)

            let client = make(cache: cache) { _ in
                requestCount += 1
                return response(statusCode: 200, data: expected)
            }

            _ = try await client.requestData(endpoint: endpoint)
            _ = try await client.requestData(endpoint: endpoint)

            #expect(requestCount == 2)
        }

        @Test("Network-only policy bypasses cached value")
        func networkOnlyBypassesCachedValue() async throws {
            let expected = Data("fresh-response".utf8)
            // See `retriesOn503AndSucceeds`, same "called serially within this test" rationale.
            nonisolated(unsafe) var requestCount = 0
            let cache = DataCache(ttl: 60)

            let client = make(cache: cache) { _ in
                requestCount += 1
                return response(statusCode: 200, data: expected)
            }

            _ = try await client.requestData(endpoint: .mock)
            _ = try await client.requestData(endpoint: .mock, cachePolicy: .networkOnly)

            #expect(requestCount == 2)
        }

        @Test("Requests to the same URL with different headers do not share a cache entry")
        func differentHeadersDoNotShareCacheEntry() async throws {
            // See `retriesOn503AndSucceeds`, same "called serially within this test" rationale.
            nonisolated(unsafe) var requestCount = 0
            let cache = DataCache(ttl: 60)
            let baseURL = try #require(URL(string: "https://example.com"))

            let client = make(cache: cache) { _ in
                requestCount += 1
                return response(statusCode: 200, data: Data("payload".utf8))
            }

            let endpointA = Endpoint(baseURL: baseURL, path: "mock", headers: ["Accept-Language": "en"])
            let endpointB = Endpoint(baseURL: baseURL, path: "mock", headers: ["Accept-Language": "fr"])

            _ = try await client.requestData(endpoint: endpointA)
            _ = try await client.requestData(endpoint: endpointB)

            #expect(requestCount == 2)
        }

        @Test("Concurrent requests for the same resource coalesce into a single network call")
        func concurrentRequestsCoalesce() async throws {
            let expected = Data("coalesced-response".utf8)
            let requestCount = CountingActor()

            let client = make(asyncHandler: { _ in
                await requestCount.increment()
                // Give both callers a chance to have already entered `requestData` before the
                // in-flight request resolves, so this actually exercises coalescing rather than
                // two calls that happen to run sequentially.
                try? await Task.sleep(for: .milliseconds(50))
                return response(statusCode: 200, data: expected)
            })

            async let first = client.requestData(endpoint: .mock)
            async let second = client.requestData(endpoint: .mock)
            let (firstResult, secondResult) = try await (first, second)

            #expect(firstResult == expected)
            #expect(secondResult == expected)
            let count = await requestCount.value
            #expect(count == 1)
        }

        @Test("A concurrent .networkOnly request does not join a .useCache request's in-flight task")
        func networkOnlyDoesNotCoalesceWithUseCache() async throws {
            let requestCount = CountingActor()

            let client = make(asyncHandler: { _ in
                let count = await requestCount.increment()
                // Slow enough that both requests are guaranteed to be in flight together.
                try? await Task.sleep(for: .milliseconds(50))
                return response(statusCode: 200, data: Data("response-\(count)".utf8))
            })

            async let useCacheResult = client.requestData(endpoint: .mock, cachePolicy: .useCache)
            async let networkOnlyResult = client.requestData(endpoint: .mock, cachePolicy: .networkOnly)
            _ = try await (useCacheResult, networkOnlyResult)

            let count = await requestCount.value
            #expect(count == 2, ".networkOnly must always fire its own request, never join another caller's in-flight fetch")
        }

        @Test("Only the coalescing task's own cacheTTL is ever written, never a joiner's")
        func coalescedWriteUsesCreatorsTTLOnly() async throws {
            let cache = DataCache()
            let baseURL = try #require(URL(string: "https://example.com"))
            let creatorTTL: TimeInterval = 5
            let joinerTTL: TimeInterval = 999

            let client = make(cache: cache, asyncHandler: { _ in
                try? await Task.sleep(for: .milliseconds(50))
                return response(statusCode: 200, data: Data("payload".utf8))
            })

            let creatorEndpoint = Endpoint(baseURL: baseURL, path: "mock", cacheTTL: creatorTTL)
            let joinerEndpoint = Endpoint(baseURL: baseURL, path: "mock", cacheTTL: joinerTTL)

            async let creator: Data = client.requestData(endpoint: creatorEndpoint)
            // Give the creator a moment to actually register the in-flight task before the
            // "joiner" call is made, so it reliably joins rather than racing to create its own.
            try? await Task.sleep(for: .milliseconds(10))
            async let joiner: Data = client.requestData(endpoint: joinerEndpoint)
            _ = try await (creator, joiner)

            let cacheKey = "GET|https://example.com/mock|"
            let cached = await cache.cachedValue(for: cacheKey)
            #expect(cached?.metadata.ttl == creatorTTL)
            #expect(cached?.metadata.ttl != joinerTTL)
        }
    }
}

private actor CountingActor {
    private(set) var value = 0

    @discardableResult
    func increment() -> Int {
        value += 1
        return value
    }
}

// MARK: - Helpers

extension URLSessionNetworkClientTests {
    typealias AsyncThrowingOperation = () async throws -> Void

    static func make(retryPolicy: RetryPolicy = MockRetryPolicy(),
                     logger: NetworkLogger = MockLogger(),
                     cache: DataCache = DataCache(),
                     handler: @escaping MockNetworkSession.Handler) -> URLSessionNetworkClient
    {
        URLSessionNetworkClient(
            session: MockNetworkSession(handler: handler),
            decoder: JSONDecoder(),
            retryPolicy: retryPolicy,
            logger: logger,
            cache: cache
        )
    }

    static func make(retryPolicy: RetryPolicy = MockRetryPolicy(),
                     logger: NetworkLogger = MockLogger(),
                     cache: DataCache = DataCache(),
                     asyncHandler: @escaping MockNetworkSession.AsyncHandler) -> URLSessionNetworkClient
    {
        URLSessionNetworkClient(
            session: MockNetworkSession(asyncHandler: asyncHandler),
            decoder: JSONDecoder(),
            retryPolicy: retryPolicy,
            logger: logger,
            cache: cache
        )
    }

    static func response(statusCode: Int, data: Data = Data()) -> (Data, URLResponse) {
        (data, HTTPURLResponse.make(statusCode: statusCode))
    }

    static func nonHTTPResponse(for request: URLRequest) -> (Data, URLResponse) {
        let url = request.url ?? URL(string: "https://example.com")!
        let response = URLResponse(
            url: url,
            mimeType: nil,
            expectedContentLength: 0,
            textEncodingName: nil
        )
        return (Data(), response)
    }

    static func retryOnStatusCode(_ statusCode: Int, maxAttempts: Int) -> RetryPolicy {
        MockRetryPolicy(
            shouldRetryHandler: { error, attempt, _ in
                guard let networkError = error as? NetworkError,
                      case let .statusCode(code) = networkError
                else { return false }
                return code == statusCode && attempt < maxAttempts
            }
        )
    }

    static func assertThrowsStatusCode(_ expectedStatusCode: Int, operation: AsyncThrowingOperation) async {
        do {
            try await operation()
            Issue.record("Expected statusCode(\(expectedStatusCode)) error to be thrown")
        } catch let error as NetworkError {
            if case let .statusCode(code) = error {
                #expect(code == expectedStatusCode)
            } else {
                Issue.record("Expected statusCode(\(expectedStatusCode)), got \(error)")
            }
        } catch {
            Issue.record("Expected NetworkError.statusCode(\(expectedStatusCode)), got \(error)")
        }
    }

    static func assertThrowsDecodingError(operation: AsyncThrowingOperation) async {
        do {
            try await operation()
            Issue.record("Expected decoding error to be thrown")
        } catch let error as NetworkError {
            if case .decoding = error {
                // expected
            } else {
                Issue.record("Expected decoding error, got \(error)")
            }
        } catch {
            Issue.record("Expected NetworkError.decoding, got \(error)")
        }
    }

    static func assertThrowsInvalidResponse(operation: AsyncThrowingOperation) async {
        do {
            try await operation()
            Issue.record("Expected invalidResponse error to be thrown")
        } catch let error as NetworkError {
            if case .invalidResponse = error {
                // expected
            } else {
                Issue.record("Expected invalidResponse error, got \(error)")
            }
        } catch {
            Issue.record("Expected NetworkError.invalidResponse, got \(error)")
        }
    }
}

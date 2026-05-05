//
//  URLSessionNetworkClientTests.swift
//  TMinus
//
//  Created by Sadegh on 01/05/2026.
//

@testable import TMinus
import Testing
import Foundation

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
        func throwsStatusCodeError(statusCode: Int) async throws {
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
        func throwsDecodingErrorOnInvalidJSON() async throws {
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
            var attemptCount = 0

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
        func exhaustsRetriesAndThrows() async throws {
            var attemptCount = 0

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
        func throwsInvalidResponse() async throws {
            let client = make { request in
                nonHTTPResponse(for: request)
            }

            await assertThrowsInvalidResponse {
                _ = try await client.requestData(endpoint: .mock)
            }
        }
    }
}

// MARK: - Helpers

extension URLSessionNetworkClientTests {
    typealias AsyncThrowingOperation = () async throws -> Void

    static func make(retryPolicy: RetryPolicy = MockRetryPolicy(),
                     logger: NetworkLogger = MockLogger(),
                     handler: @escaping MockNetworkSession.Handler) -> URLSessionNetworkClient {
        URLSessionNetworkClient(
            baseURL: URL(string: "https://example.com")!,
            session: MockNetworkSession(handler: handler),
            decoder: JSONDecoder(),
            retryPolicy: retryPolicy,
            logger: logger)
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
            textEncodingName: nil)
        return (Data(), response)
    }

    static func retryOnStatusCode(_ statusCode: Int, maxAttempts: Int) -> RetryPolicy {
        MockRetryPolicy(
            shouldRetryHandler: { error, attempt in
                guard let networkError = error as? NetworkError,
                      case let .statusCode(code) = networkError
                else { return false }
                return code == statusCode && attempt < maxAttempts
            })
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

//
//  DefaultRetryPolicyTests.swift
//  TMinus
//
//  Created by Sadegh on 30/04/2026.
//

import Foundation
import Testing
@testable import TMinus

// MARK: - DefaultRetryPolicyTests

@Suite("DefaultRetryPolicy")
enum DefaultRetryPolicyTests {
    // MARK: - Initialization

    @Suite("Initialization")
    struct Initialization {
        @Test("Accepts minimum valid maxAttempts of 1")
        func acceptsMinimumValidMaxAttempts() {
            #expect(throws: Never.self) {
                _ = makePolicy(maxRetries: 1)
            }
        }

        @Test("Accepts valid maxAttempts", arguments: [1, 2, 3, 10])
        func acceptsValidMaxAttempts(maxAttempts: Int) {
            #expect(throws: Never.self) {
                _ = makePolicy(maxRetries: maxAttempts)
            }
        }

        @Test("Default maxAttempts is 3")
        func defaultMaxAttempts() {
            let policy = makePolicy()
            #expect(policy.maxRetries == 3)
        }
    }

    // MARK: - Status Code Retries

    @Suite("Status Code Retries")
    struct StatusCodeRetries {
        @Test("Retries on 429", arguments: [0, 1, 2])
        func retriesOn429(attempt: Int) {
            assertShouldRetry(true, error: NetworkError.statusCode(429), attempt: attempt)
        }

        @Test("Retries on any 5xx server error", arguments: [500, 502, 503, 504, 599])
        func retriesOn5xx(statusCode: Int) {
            assertShouldRetry(true, error: NetworkError.statusCode(statusCode), attempt: 0)
        }

        @Test("Does not retry on non-retryable status codes", arguments: [
            400, 401, 403, 404
        ])
        func doesNotRetryOnNonRetryableStatusCodes(statusCode: Int) {
            assertShouldRetry(false, error: NetworkError.statusCode(statusCode), attempt: 0)
        }

        @Test("Does not retry when attempts exhausted on retryable status codes", arguments: [
            NetworkError.statusCode(429),
            NetworkError.statusCode(500),
            NetworkError.statusCode(503)
        ])
        func doesNotRetryWhenAttemptsExhausted(error: NetworkError) {
            assertShouldRetry(false, error: error, attempt: 3)
        }
    }

    // MARK: - URLError Retries

    @Suite("URLError Retries")
    struct URLErrorRetries {
        @Test("Retries on timed out error", arguments: [0, 1, 2])
        func retriesOnTimedOut(attempt: Int) {
            assertShouldRetry(true, error: NetworkError.transport(URLError(.timedOut)), attempt: attempt)
        }

        @Test("Retries on network connection lost", arguments: [0, 1, 2])
        func retriesOnNetworkConnectionLost(attempt: Int) {
            assertShouldRetry(true, error: NetworkError.transport(URLError(.networkConnectionLost)), attempt: attempt)
        }

        @Test("Does not retry on non-retryable URLErrors", arguments: [
            URLError.Code.cancelled,
            URLError.Code.badURL,
            URLError.Code.unsupportedURL,
            URLError.Code.notConnectedToInternet
        ])
        func doesNotRetryOnNonRetryableURLErrors(code: URLError.Code) {
            DefaultRetryPolicyTests.assertShouldRetry(false, error: NetworkError.transport(URLError(code)), attempt: 0)
        }

        @Test("Does not retry transport error when attempts exhausted")
        func doesNotRetryTransportWhenAttemptsExhausted() {
            assertShouldRetry(false, error: NetworkError.transport(URLError(.timedOut)), attempt: 3)
        }
    }

    // MARK: - Non-Retryable Error Types

    @Suite("Non-Retryable Error Types")
    struct NonRetryableErrorTypes {
        @Test("Does not retry on decoding error")
        func doesNotRetryOnDecodingError() {
            let error = NetworkError.decoding(DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "")))
            assertShouldRetry(false, error: error, attempt: 0)
        }

        @Test("Does not retry on invalid response")
        func doesNotRetryOnInvalidResponse() {
            assertShouldRetry(false, error: NetworkError.invalidResponse, attempt: 0)
        }

        @Test("Does not retry on unknown error")
        func doesNotRetryOnUnknownError() {
            assertShouldRetry(false, error: NetworkError.unknown(underlying: URLError(.unknown)), attempt: 0)
        }

        @Test("Does not retry on non-NetworkError types")
        func doesNotRetryOnNonNetworkError() {
            let error = NSError(domain: "test", code: 0)
            assertShouldRetry(false, error: error, attempt: 0)
        }
    }

    // MARK: - Idempotency

    @Suite("Idempotency")
    struct Idempotency {
        @Test("Never retries a POST even on an otherwise-retryable error")
        func doesNotRetryNonIdempotentMethod() {
            DefaultRetryPolicyTests.assertShouldRetry(
                false,
                error: NetworkError.statusCode(503),
                attempt: 0,
                method: .post
            )
        }

        @Test("Retries a PUT on an otherwise-retryable error")
        func retriesIdempotentPut() {
            DefaultRetryPolicyTests.assertShouldRetry(
                true,
                error: NetworkError.statusCode(503),
                attempt: 0,
                method: .put
            )
        }
    }

    // MARK: - Delay

    @Suite("Delay")
    struct DelayTests {
        @Test("Delay increases with attempt number")
        func delayIncreasesWithAttempt() {
            let policy = DefaultRetryPolicyTests.makePolicy()
            let delay0 = policy.delay(for: 0, retryAfter: nil)
            let delay1 = policy.delay(for: 1, retryAfter: nil)
            let delay2 = policy.delay(for: 2, retryAfter: nil)

            #expect(delay1 > delay0)
            #expect(delay2 > delay1)
        }

        @Test("Delay is within expected range for attempt 0")
        func delayRangeForAttempt0() {
            let policy = DefaultRetryPolicyTests.makePolicy()
            let delay = policy.delay(for: 0, retryAfter: nil)

            // base = 1.0, jitter = 0...base, range is 1.0...2.0 seconds
            #expect(delay >= .seconds(1.0))
            #expect(delay <= .seconds(2.0))
        }

        @Test("Delay is within expected range for attempt 1")
        func delayRangeForAttempt1() {
            let policy = DefaultRetryPolicyTests.makePolicy()
            let delay = policy.delay(for: 1, retryAfter: nil)

            // base = 2.0, jitter = 0...base, range is 2.0...4.0 seconds
            #expect(delay >= .seconds(2.0))
            #expect(delay <= .seconds(4.0))
        }

        @Test("Delay is within expected range for attempt 2")
        func delayRangeForAttempt2() {
            let policy = DefaultRetryPolicyTests.makePolicy()
            let delay = policy.delay(for: 2, retryAfter: nil)

            // base = 4.0, jitter = 0...base, range is 4.0...8.0 seconds
            #expect(delay >= .seconds(4.0))
            #expect(delay <= .seconds(8.0))
        }

        @Test("Retry-After header takes precedence over computed backoff")
        func retryAfterTakesPrecedence() {
            let policy = DefaultRetryPolicyTests.makePolicy()
            let delay = policy.delay(for: 0, retryAfter: 12)

            #expect(delay == .seconds(12))
        }

        @Test("Retry-After is honored even when it exceeds the exponential-backoff max delay")
        func retryAfterIsNotCappedByBackoffMaxDelay() {
            // The server's explicit instruction is respected as-is here; bounding the overall
            // wait against the request's own retry deadline is `URLSessionNetworkClient`'s job,
            // not this policy's, see the doc comment on `delay(for:retryAfter:)`.
            let policy = DefaultRetryPolicyTests.makePolicy()
            let delay = policy.delay(for: 0, retryAfter: 9999)

            #expect(delay == .seconds(9999))
        }
    }
}

private extension DefaultRetryPolicyTests {
    static func makePolicy(maxRetries: Int = 3) -> DefaultRetryPolicy {
        DefaultRetryPolicy(maxRetries: maxRetries)
    }

    static func assertShouldRetry(_ expected: Bool,
                                  error: Error,
                                  attempt: Int,
                                  maxRetries: Int = 3,
                                  method: HTTPMethod = .get)
    {
        let policy = makePolicy(maxRetries: maxRetries)
        #expect(policy.shouldRetry(error: error, attempt: attempt, method: method) == expected)
    }
}

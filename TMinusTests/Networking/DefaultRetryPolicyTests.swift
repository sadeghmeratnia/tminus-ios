//
//  DefaultRetryPolicyTests.swift
//  TMinus
//
//  Created by Sadegh on 30/04/2026.
//


import Testing
import Foundation
@testable import TMinus

@Suite("DefaultRetryPolicy")
struct DefaultRetryPolicyTests {

    // MARK: - Initialization

    @Suite("Initialization")
    struct Initialization {

        @Test("Accepts minimum valid maxAttempts of 1")
        func acceptsMinimumValidMaxAttempts() {
            #expect(throws: Never.self) {
                _ = DefaultRetryPolicy(maxAttempts: 1)
            }
        }

        @Test("Accepts valid maxAttempts", arguments: [1, 2, 3, 10])
        func acceptsValidMaxAttempts(maxAttempts: Int) {
            #expect(throws: Never.self) {
                _ = DefaultRetryPolicy(maxAttempts: maxAttempts)
            }
        }

        @Test("Default maxAttempts is 3")
        func defaultMaxAttempts() {
            let policy = DefaultRetryPolicy()
            #expect(policy.maxAttempts == 3)
        }
    }

    // MARK: - Status Code Retries

    @Suite("Status Code Retries")
    struct StatusCodeRetries {

        @Test("Retries on 429", arguments: [0, 1, 2])
        func retriesOn429(attempt: Int) {
            let policy = DefaultRetryPolicy()
            let error = NetworkError.statusCode(429)
            #expect(policy.shouldRetry(error: error, attempt: attempt) == true)
        }

        @Test("Retries on 503", arguments: [0, 1, 2])
        func retriesOn503(attempt: Int) {
            let policy = DefaultRetryPolicy(maxAttempts: 3)
            let error = NetworkError.statusCode(503)
            #expect(policy.shouldRetry(error: error, attempt: attempt) == true)
        }

        @Test("Does not retry on non-retryable status codes", arguments: [
            400, 401, 403, 404, 500, 502
        ])
        func doesNotRetryOnNonRetryableStatusCodes(statusCode: Int) {
            let policy = DefaultRetryPolicy(maxAttempts: 3)
            let error = NetworkError.statusCode(statusCode)
            #expect(policy.shouldRetry(error: error, attempt: 0) == false)
        }

        @Test("Does not retry when attempts exhausted on retryable status codes", arguments: [
            NetworkError.statusCode(429),
            NetworkError.statusCode(503)
        ])
        func doesNotRetryWhenAttemptsExhausted(error: NetworkError) {
            let policy = DefaultRetryPolicy(maxAttempts: 3)
            #expect(policy.shouldRetry(error: error, attempt: 3) == false)
        }
    }

    // MARK: - URLError Retries

    @Suite("URLError Retries")
    struct URLErrorRetries {

        @Test("Retries on timed out error", arguments: [0, 1, 2])
        func retriesOnTimedOut(attempt: Int) {
            let policy = DefaultRetryPolicy(maxAttempts: 3)
            let error = NetworkError.transport(URLError(.timedOut))
            #expect(policy.shouldRetry(error: error, attempt: attempt) == true)
        }

        @Test("Retries on network connection lost", arguments: [0, 1, 2])
        func retriesOnNetworkConnectionLost(attempt: Int) {
            let policy = DefaultRetryPolicy(maxAttempts: 3)
            let error = NetworkError.transport(URLError(.networkConnectionLost))
            #expect(policy.shouldRetry(error: error, attempt: attempt) == true)
        }

        @Test("Does not retry on non-retryable URLErrors", arguments: [
            URLError.Code.cancelled,
            URLError.Code.badURL,
            URLError.Code.unsupportedURL,
            URLError.Code.notConnectedToInternet
        ])
        func doesNotRetryOnNonRetryableURLErrors(code: URLError.Code) {
            let policy = DefaultRetryPolicy(maxAttempts: 3)
            let error = NetworkError.transport(URLError(code))
            #expect(policy.shouldRetry(error: error, attempt: 0) == false)
        }

        @Test("Does not retry transport error when attempts exhausted")
        func doesNotRetryTransportWhenAttemptsExhausted() {
            let policy = DefaultRetryPolicy(maxAttempts: 3)
            let error = NetworkError.transport(URLError(.timedOut))
            #expect(policy.shouldRetry(error: error, attempt: 3) == false)
        }
    }

    // MARK: - Non-Retryable Error Types

    @Suite("Non-Retryable Error Types")
    struct NonRetryableErrorTypes {

        @Test("Does not retry on decoding error")
        func doesNotRetryOnDecodingError() {
            let policy = DefaultRetryPolicy(maxAttempts: 3)
            let error = NetworkError.decoding(DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "")))
            #expect(policy.shouldRetry(error: error, attempt: 0) == false)
        }

        @Test("Does not retry on invalid response")
        func doesNotRetryOnInvalidResponse() {
            let policy = DefaultRetryPolicy(maxAttempts: 3)
            #expect(policy.shouldRetry(error: NetworkError.invalidResponse, attempt: 0) == false)
        }

        @Test("Does not retry on unknown error")
        func doesNotRetryOnUnknownError() {
            let policy = DefaultRetryPolicy(maxAttempts: 3)
            let error = NetworkError.unknown(underlying: URLError(.unknown))
            #expect(policy.shouldRetry(error: error, attempt: 0) == false)
        }

        @Test("Does not retry on non-NetworkError types")
        func doesNotRetryOnNonNetworkError() {
            let policy = DefaultRetryPolicy(maxAttempts: 3)
            let error = NSError(domain: "test", code: 0)
            #expect(policy.shouldRetry(error: error, attempt: 0) == false)
        }
    }

    // MARK: - Delay

    @Suite("Delay")
    struct DelayTests {

        @Test("Delay increases with attempt number")
        func delayIncreasesWithAttempt() {
            let policy = DefaultRetryPolicy()
            let delay0 = policy.delay(for: 0)
            let delay1 = policy.delay(for: 1)
            let delay2 = policy.delay(for: 2)

            #expect(delay1 > delay0)
            #expect(delay2 > delay1)
        }

        @Test("Delay is within expected range for attempt 0")
        func delayRangeForAttempt0() {
            let policy = DefaultRetryPolicy()
            let delay = policy.delay(for: 0)

            // base = 1.0, jitter = 0...1.0, range is 1.0...2.0 seconds
            let minDelay = UInt64(1.0 * 1_000_000_000)
            let maxDelay = UInt64(2.0 * 1_000_000_000)
            #expect(delay >= minDelay)
            #expect(delay <= maxDelay)
        }

        @Test("Delay is within expected range for attempt 1")
        func delayRangeForAttempt1() {
            let policy = DefaultRetryPolicy()
            let delay = policy.delay(for: 1)

            // base = 2.0, jitter = 0...1.0, range is 2.0...3.0 seconds
            let minDelay = UInt64(2.0 * 1_000_000_000)
            let maxDelay = UInt64(3.0 * 1_000_000_000)
            #expect(delay >= minDelay)
            #expect(delay <= maxDelay)
        }

        @Test("Delay is within expected range for attempt 2")
        func delayRangeForAttempt2() {
            let policy = DefaultRetryPolicy()
            let delay = policy.delay(for: 2)

            // base = 4.0, jitter = 0...1.0, range is 4.0...5.0 seconds
            let minDelay = UInt64(4.0 * 1_000_000_000)
            let maxDelay = UInt64(5.0 * 1_000_000_000)
            #expect(delay >= minDelay)
            #expect(delay <= maxDelay)
        }
    }
}

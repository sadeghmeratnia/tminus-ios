//
//  NetworkErrorClassifierTests.swift
//  TMinusTests
//
//  Created by Sadegh on 09/07/2026.
//

import Foundation
import Testing
@testable import TMinus

@Suite("NetworkErrorClassifier")
enum NetworkErrorClassifierTests {
    @Test("Classifies transport errors as network unavailable")
    static func classifiesTransport() {
        let classification = NetworkErrorClassifier.classify(NetworkError.transport(URLError(.notConnectedToInternet)))

        guard case .networkUnavailable = classification else {
            Issue.record("Expected .networkUnavailable, got \(classification)")
            return
        }
    }

    @Test("Classifies timed out transport errors as timeout rather than network unavailable")
    static func classifiesTimeout() {
        let classification = NetworkErrorClassifier.classify(NetworkError.transport(URLError(.timedOut)))

        guard case .timeout = classification else {
            Issue.record("Expected .timeout, got \(classification)")
            return
        }
    }

    @Test("Classifies non-connectivity transport errors as unknown rather than network unavailable")
    static func classifiesNonConnectivityTransportAsUnknown() {
        let codes: [URLError.Code] = [.cannotFindHost, .secureConnectionFailed, .badServerResponse]
        for code in codes {
            let classification = NetworkErrorClassifier.classify(NetworkError.transport(URLError(code)))
            guard case .unknown = classification else {
                Issue.record("Expected .unknown for \(code), got \(classification)")
                return
            }
        }
    }

    @Test("Classifies 401 and 403 as unauthorized", arguments: [401, 403])
    static func classifiesUnauthorized(code: Int) {
        let classification = NetworkErrorClassifier.classify(NetworkError.statusCode(code))

        guard case .unauthorized = classification else {
            Issue.record("Expected .unauthorized, got \(classification)")
            return
        }
    }

    @Test("Classifies 429 as rate limited")
    static func classifiesRateLimited() {
        let classification = NetworkErrorClassifier.classify(NetworkError.statusCode(429))

        guard case .rateLimited = classification else {
            Issue.record("Expected .rateLimited, got \(classification)")
            return
        }
    }

    @Test("Classifies 5xx as server error", arguments: [500, 502, 503])
    static func classifiesServerError(code: Int) {
        let classification = NetworkErrorClassifier.classify(NetworkError.statusCode(code))

        guard case .serverError = classification else {
            Issue.record("Expected .serverError, got \(classification)")
            return
        }
    }

    @Test("Classifies decoding errors as decoding failed")
    static func classifiesDecodingFailed() {
        let underlying = NSError(domain: "test", code: 1)
        let classification = NetworkErrorClassifier.classify(NetworkError.decoding(underlying))

        guard case .decodingFailed = classification else {
            Issue.record("Expected .decodingFailed, got \(classification)")
            return
        }
    }

    @Test("Classifies other 4xx status codes as clientError")
    static func classifiesClientError() {
        let unhandledStatus = NetworkErrorClassifier.classify(NetworkError.statusCode(418))
        guard case let .clientError(statusCode) = unhandledStatus else {
            Issue.record("Expected .clientError, got \(unhandledStatus)")
            return
        }
        #expect(statusCode == 418)
    }

    @Test("Classifies non-4xx/5xx status codes and non-network errors as unknown")
    static func classifiesUnknown() {
        let outOfRangeStatus = NetworkErrorClassifier.classify(NetworkError.statusCode(302))
        guard case .unknown = outOfRangeStatus else {
            Issue.record("Expected .unknown, got \(outOfRangeStatus)")
            return
        }

        let foreignError = NetworkErrorClassifier.classify(NSError(domain: "test", code: 2))
        guard case .unknown = foreignError else {
            Issue.record("Expected .unknown, got \(foreignError)")
            return
        }
    }

    // Regression test: `NetworkError.unknown(underlying:)` previously got re-summarized from the
    // outer `NetworkError` case itself rather than the wrapped error, discarding its real
    // domain/code (e.g. the original `NSURLErrorDomain` code) behind a generic Swift-bridged one
    //, exactly the failure mode `.transport`'s own summarization deliberately avoids.
    @Test("Classifying .unknown(underlying:) preserves the wrapped error's real domain and code")
    static func classifiesUnknownPreservesWrappedErrorIdentity() {
        let underlying = NSError(domain: "com.example.diagnostic", code: 42)
        let classification = NetworkErrorClassifier.classify(NetworkError.unknown(underlying: underlying))

        guard case let .unknown(summary) = classification else {
            Issue.record("Expected .unknown, got \(classification)")
            return
        }
        #expect(summary.domain == "com.example.diagnostic")
        #expect(summary.code == 42)
    }
}

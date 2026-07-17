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

    @Test("Classifies other status codes and non-network errors as unknown")
    static func classifiesUnknown() {
        let unhandledStatus = NetworkErrorClassifier.classify(NetworkError.statusCode(418))
        guard case .unknown = unhandledStatus else {
            Issue.record("Expected .unknown, got \(unhandledStatus)")
            return
        }

        let foreignError = NetworkErrorClassifier.classify(NSError(domain: "test", code: 2))
        guard case .unknown = foreignError else {
            Issue.record("Expected .unknown, got \(foreignError)")
            return
        }
    }
}

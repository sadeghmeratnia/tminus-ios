//
//  DefaultRetryPolicy.swift
//  TMinus
//
//  Created by Sadegh on 29/04/2026.
//

import Foundation

struct DefaultRetryPolicy: RetryPolicy {
    let maxRetries: Int

    init(maxRetries: Int = 3) {
        precondition(maxRetries >= 1, "maxRetries must be at least 1")
        self.maxRetries = maxRetries
    }

    func shouldRetry(error: Error, attempt: Int) -> Bool {
        guard attempt < maxRetries else { return false }

        switch error {
        case let networkError as NetworkError:
            switch networkError {
            case let .statusCode(code):
                return code == 429 || code == 503
            case let .transport(urlError):
                return urlError.code == .timedOut || urlError.code == .networkConnectionLost
            default:
                return false
            }
        default:
            return false
        }
    }

    func delay(for attempt: Int) -> UInt64 {
        let base = pow(2.0, Double(attempt))
        let jitter = Double.random(in: 0 ... 1.0)
        return UInt64((base + jitter) * 1_000_000_000)
    }
}

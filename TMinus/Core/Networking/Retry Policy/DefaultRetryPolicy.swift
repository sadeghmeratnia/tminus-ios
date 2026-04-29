//
//  DefaultRetryPolicy.swift
//  TMinus
//
//  Created by Sadegh on 29/04/2026.
//

import Foundation

struct DefaultRetryPolicy: RetryPolicy {
    let maxAttempts: Int

    init(maxAttempts: Int = 3) {
        precondition(maxAttempts >= 1, "maxAttempts must be at least 1")
        self.maxAttempts = maxAttempts
    }

    func shouldRetry(error: Error, attempt: Int) -> Bool {
        guard attempt < maxAttempts else { return false }

        switch error {
        case let networkError as NetworkError:
            switch networkError {
            case .statusCode(let code):
                return code == 429 || code == 503
            case .transport(let urlError):
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
        let jitter = Double.random(in: 0...1.0)
        return UInt64((base + jitter) * 1_000_000_000)
    }
}

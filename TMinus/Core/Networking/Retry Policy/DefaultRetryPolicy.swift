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

    func shouldRetry(error: Error, attempt: Int, method: HTTPMethod) -> Bool {
        guard attempt < maxRetries, method.isIdempotent else { return false }

        switch error {
        case let networkError as NetworkError:
            switch networkError {
            case let .statusCode(code):
                return code == 429 || code >= 500
            case let .transport(urlError):
                return urlError.code == .timedOut || urlError.code == .networkConnectionLost
            default:
                return false
            }
        default:
            return false
        }
    }

    func delay(for attempt: Int, retryAfter: TimeInterval?) -> Duration {
        if let retryAfter, retryAfter >= 0 {
            // Deliberately not capped at `maxDelaySeconds`, that cap exists to bound the
            // exponential-backoff *guess* below, but `Retry-After` is the server explicitly
            // telling the client when it's safe to come back; silently retrying sooner than that
            // (e.g. clamping a 120s instruction down to 30s) undermines the exact rate-limiting
            // the header exists to enforce. `URLSessionNetworkClient.retryOrThrow` already clamps
            // whatever this returns to the time left before its own `maxRetryWindow` deadline, so
            // a large `Retry-After` still can't stall a request past that ceiling.
            return .seconds(retryAfter)
        }
        let base = pow(2.0, Double(attempt))
        // Full jitter scaled to the backoff base (not a fixed 0...1s), a fixed jitter window
        // barely spreads out retries at higher attempt counts (e.g. attempt=4 → 16-17s), so
        // concurrent clients retrying after a shared outage still cluster together.
        let jitter = Double.random(in: 0 ... base)
        let seconds = min(base + jitter, Constants.maxDelaySeconds)
        return .seconds(seconds)
    }
}

// MARK: - Constants

extension DefaultRetryPolicy {
    private enum Constants {
        /// Caps exponential backoff so a large `maxRetries` can't produce multi-minute sleeps.
        static let maxDelaySeconds: Double = 30
    }
}

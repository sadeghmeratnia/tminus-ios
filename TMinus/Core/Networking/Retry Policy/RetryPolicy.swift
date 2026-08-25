//
//  RetryPolicy.swift
//  TMinus
//
//  Created by Sadegh on 29/04/2026.
//

import Foundation

protocol RetryPolicy: Sendable {
    /// `method` gates retries on idempotency: a policy must never retry a non-idempotent request
    /// (e.g. POST) automatically, since the original request may already have taken effect
    /// server-side before its response was lost.
    func shouldRetry(error: Error, attempt: Int, method: HTTPMethod) -> Bool
    /// `retryAfter`, when the failed response carried a `Retry-After` header, should take
    /// precedence over the policy's own backoff calculation, the server is telling the client
    /// exactly how long to wait.
    func delay(for attempt: Int, retryAfter: TimeInterval?) -> Duration
}

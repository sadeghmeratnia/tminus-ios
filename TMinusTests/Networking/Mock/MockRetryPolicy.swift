//
//  MockRetryPolicy.swift
//  TMinus
//
//  Created by Sadegh on 05/05/2026.
//

import Foundation
@testable import TMinus

struct MockRetryPolicy: RetryPolicy {
    var shouldRetryHandler: @Sendable (Error, Int, HTTPMethod) -> Bool = { _, _, _ in false }
    var delayHandler: @Sendable (Int, TimeInterval?) -> Duration = { _, _ in .zero }

    func shouldRetry(error: Error, attempt: Int, method: HTTPMethod) -> Bool {
        shouldRetryHandler(error, attempt, method)
    }

    func delay(for attempt: Int, retryAfter: TimeInterval?) -> Duration {
        delayHandler(attempt, retryAfter)
    }
}

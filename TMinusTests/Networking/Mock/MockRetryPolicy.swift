//
//  MockRetryPolicy.swift
//  TMinus
//
//  Created by Sadegh on 05/05/2026.
//

@testable import TMinus
import Foundation

struct MockRetryPolicy: RetryPolicy {
    var shouldRetryHandler: (Error, Int) -> Bool = { _, _ in false }
    var delayHandler: (Int) -> UInt64 = { _ in 0 }

    func shouldRetry(error: Error, attempt: Int) -> Bool {
        shouldRetryHandler(error, attempt)
    }

    func delay(for attempt: Int) -> UInt64 {
        delayHandler(attempt)
    }
}

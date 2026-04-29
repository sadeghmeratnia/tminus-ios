//
//  RetryPolicy.swift
//  TMinus
//
//  Created by Sadegh on 29/04/2026.
//

import Foundation

protocol RetryPolicy {
    func shouldRetry(error: Error, attempt: Int) -> Bool
    func delay(for attempt: Int) -> UInt64
}

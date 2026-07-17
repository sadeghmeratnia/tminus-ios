//
//  ErrorSummary.swift
//  TMinus
//
//  Created by Sadegh on 13/07/2026.
//

import Foundation

/// A `Sendable`, `Equatable` snapshot of an `Error`, captured at the point it's caught rather
/// than holding onto the original. This exists because a generic `catch` block's bound error is
/// typed as plain `any Error`, which the compiler can't prove is `Sendable` — but nothing
/// downstream needs the *live* error object for the "unclassified" bucket (`NetworkError`,
/// `LaunchError`, `NewsError`'s `.unknown` case) it's used in, only a description of what went
/// wrong. Capturing that description up front, in fields that are themselves trivially
/// `Sendable`, avoids ever needing an `@unchecked Sendable` escape hatch.
struct ErrorSummary: Error, Equatable {
    let domain: String
    let code: Int
    let debugDescription: String

    init(_ error: Error) {
        let nsError = error as NSError
        domain = nsError.domain
        code = nsError.code
        debugDescription = String(describing: error)
    }
}

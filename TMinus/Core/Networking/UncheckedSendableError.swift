//
//  UncheckedSendableError.swift
//  TMinus
//
//  Created by Sadegh on 13/07/2026.
//

import Foundation

/// Wraps a non-statically-Sendable `Error` so it can be stored in a `Sendable` error enum
/// (`NetworkError`, `LaunchError`, `NewsError`). This only exists because a generic `catch`
/// block's bound error is typed as plain `any Error`, which the compiler can't prove is
/// `Sendable` even though every concrete error this app actually throws — `URLError`,
/// `DecodingError`, `NSError`, and this app's own error enums — already conforms to `Sendable`
/// in practice. The `@unchecked` is scoped to this one small, clearly-labeled type instead of
/// leaving the domain error enums unable to participate in Sendable-checked code at all.
struct UncheckedSendableError: Error, @unchecked Sendable {
    let base: Error

    init(_ base: Error) {
        self.base = base
    }
}

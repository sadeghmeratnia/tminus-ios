//
//  AsyncTestWaiting.swift
//  TMinusTests
//
//  Shared polling helper for ViewModel tests that need to wait for an async effect to land
//  before asserting on it. Previously hand-duplicated verbatim across four test files.
//

import Foundation
import Testing

/// Polls `condition` every `checkEveryNanoseconds` until it returns `true` or `timeoutNanoseconds`
/// elapses, in which case the test is failed via `Issue.record`. `condition` runs on the main
/// actor, matching the `@MainActor` ViewModels this is used to observe.
func waitUntil(timeoutNanoseconds: UInt64 = 1_500_000_000,
               checkEveryNanoseconds: UInt64 = 20_000_000,
               _ condition: @escaping @MainActor () -> Bool) async throws
{
    let start = DispatchTime.now().uptimeNanoseconds
    while DispatchTime.now().uptimeNanoseconds - start < timeoutNanoseconds {
        if await condition() { return }
        try await Task.sleep(for: .nanoseconds(checkEveryNanoseconds))
    }
    Issue.record("Timed out waiting for expected state")
}

/// `actor`-isolated variant of `waitUntil(_:)` for polling state that lives on a plain `actor`
/// rather than `@MainActor`.
func waitUntilActor(timeoutNanoseconds: UInt64 = 1_500_000_000,
                     checkEveryNanoseconds: UInt64 = 20_000_000,
                     _ condition: @escaping () async -> Bool) async throws
{
    let start = DispatchTime.now().uptimeNanoseconds
    while DispatchTime.now().uptimeNanoseconds - start < timeoutNanoseconds {
        if await condition() { return }
        try await Task.sleep(for: .nanoseconds(checkEveryNanoseconds))
    }
    Issue.record("Timed out waiting for expected state")
}

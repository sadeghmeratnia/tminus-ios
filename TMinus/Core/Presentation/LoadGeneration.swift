//
//  LoadGeneration.swift
//  TMinus
//
//  Created by Sadegh on 14/07/2026.
//

import Foundation

/// Monotonic counter guarding a single-item detail screen's state against a response from a
/// superseded load (e.g. an earlier `retry` that's still in flight when a newer one completes)
/// clobbering it — even if task cancellation ever failed to prevent that response from arriving.
/// Shared by any detail screen using the "cancel + guard by generation" pattern, alongside the
/// shared `DetailPhase` those same screens already use.
struct LoadGeneration: Equatable {
    private(set) var current: Int

    init(current: Int = 0) {
        self.current = current
    }

    /// Returns the next generation, plus the raw value in-flight work should be tagged with —
    /// callers store the returned `LoadGeneration` in their state and pass `value` to the effect.
    func advanced() -> (next: LoadGeneration, value: Int) {
        let value = current + 1
        return (LoadGeneration(current: value), value)
    }

    /// Whether a response tagged with `value` still belongs to the current generation.
    func matches(_ value: Int) -> Bool {
        value == current
    }
}

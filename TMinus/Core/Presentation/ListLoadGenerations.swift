//
//  ListLoadGenerations.swift
//  TMinus
//
//  Created by Sadegh on 17/07/2026.
//

import Foundation

// MARK: - ListLoadGenerations

/// Per-`ListLoadKind` pair of `LoadGeneration` counters guarding a paginated list screen's state
/// against a response from a superseded load clobbering it, even if task cancellation ever fails
/// to prevent that response from arriving. A single shared counter can't be used here the way
/// detail screens use `LoadGeneration` directly: `.fresh` and `.loadMore` loads are allowed to
/// run concurrently without cancelling each other (see `ListLoadKind.cancels`), so each needs
/// its own counter — starting a `.fresh` load invalidates both (mirroring that it cancels both
/// kinds of task), while starting a `.loadMore` load only invalidates other load-mores.
struct ListLoadGenerations: Equatable {
    private var fresh: LoadGeneration
    private var loadMore: LoadGeneration

    init(fresh: LoadGeneration = LoadGeneration(), loadMore: LoadGeneration = LoadGeneration()) {
        self.fresh = fresh
        self.loadMore = loadMore
    }

    /// Returns the next generations, plus the raw value in-flight work should be tagged with —
    /// callers store the returned `ListLoadGenerations` in their state and pass `value` to the
    /// effect.
    func advancing(for kind: ListLoadKind) -> (next: ListLoadGenerations, value: Int) {
        switch kind {
        case .fresh:
            let (nextFresh, value) = fresh.advanced()
            let (nextLoadMore, _) = loadMore.advanced()
            return (ListLoadGenerations(fresh: nextFresh, loadMore: nextLoadMore), value)
        case .loadMore:
            let (nextLoadMore, value) = loadMore.advanced()
            return (ListLoadGenerations(fresh: fresh, loadMore: nextLoadMore), value)
        }
    }

    /// Whether a response of the given `kind` tagged with `value` still belongs to the current
    /// generation for that kind.
    func matches(_ value: Int, for kind: ListLoadKind) -> Bool {
        switch kind {
        case .fresh:
            return fresh.matches(value)
        case .loadMore:
            return loadMore.matches(value)
        }
    }
}

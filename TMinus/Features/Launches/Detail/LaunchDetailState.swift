//
//  LaunchDetailState.swift
//  TMinus
//
//  Created by Sadegh on 28/05/2026.
//

import Foundation

// MARK: - LaunchDetailState

struct LaunchDetailState: Equatable, Sendable {
    let launchID: String
    let launch: Launch?
    let phase: DetailPhase
    let relatedArticles: [NewsArticle]
    let loadGeneration: LoadGeneration
    /// Guards the best-effort related-news load the same way `loadGeneration` guards the main
    /// load, kept as a separate counter (rather than sharing `loadGeneration`) because the two
    /// workloads are independent (`DetailLoadTaskKind.main`/`.secondary`): a main-load refresh
    /// must not invalidate an unrelated in-flight related-news response, and vice versa.
    let relatedNewsGeneration: LoadGeneration
    /// Set once a related-news load has *succeeded* at least once (including succeeding with zero
    /// results), distinct from `relatedArticles.isEmpty`, which can't tell "never loaded"/
    /// "still loading" apart from "loaded, and this launch genuinely has none". Callers use this
    /// (not emptiness) to decide whether a related-news load is still worth retrying, so a launch
    /// with no related articles doesn't get silently re-fetched on every retry tap forever.
    let relatedNewsHasLoaded: Bool
    /// Non-nil only when a refresh failed but the previously-loaded launch is still on screen,
    /// mirrors how `ListPagination.loadMoreError` sits beside `ListPhase` rather than inside it,
    /// so a transient advisory never needs to be smuggled into a case that's meant to mean one
    /// thing.
    let refreshError: String?

    static func initial(launchID: String) -> LaunchDetailState {
        LaunchDetailState(
            launchID: launchID,
            launch: nil,
            phase: .idle,
            relatedArticles: [],
            loadGeneration: LoadGeneration(),
            relatedNewsGeneration: LoadGeneration(),
            relatedNewsHasLoaded: false,
            refreshError: nil
        )
    }

    func with(launch: Launch? = nil,
              phase: DetailPhase? = nil,
              relatedArticles: [NewsArticle]? = nil,
              loadGeneration: LoadGeneration? = nil,
              relatedNewsGeneration: LoadGeneration? = nil,
              relatedNewsHasLoaded: Bool? = nil,
              refreshError: String?? = nil) -> LaunchDetailState
    {
        LaunchDetailState(
            launchID: launchID,
            launch: launch ?? self.launch,
            phase: phase ?? self.phase,
            relatedArticles: relatedArticles ?? self.relatedArticles,
            loadGeneration: loadGeneration ?? self.loadGeneration,
            relatedNewsGeneration: relatedNewsGeneration ?? self.relatedNewsGeneration,
            relatedNewsHasLoaded: relatedNewsHasLoaded ?? self.relatedNewsHasLoaded,
            refreshError: refreshError ?? self.refreshError
        )
    }

    /// Returns the new state alongside the raw generation value the caller's effect should tag
    /// its in-flight load with.
    func startingLoad() -> (state: LaunchDetailState, generation: Int) {
        let (next, value) = loadGeneration.advanced()
        return (with(phase: .loading, loadGeneration: next, refreshError: .some(nil)), value)
    }

    /// Only valid once content is already on screen, keeps `phase` at `.loaded` and the current
    /// `launch` visible for the duration of the refresh, rather than replacing them with a
    /// spinner the way a first load does.
    func startingRefresh() -> (state: LaunchDetailState, generation: Int) {
        let (next, value) = loadGeneration.advanced()
        return (with(loadGeneration: next, refreshError: .some(nil)), value)
    }

    func applyingLoadResponse(result: LaunchDetailLoadOutcome, kind: LoadPresentationKind, generation: Int) -> LaunchDetailState {
        guard loadGeneration.matches(generation) else { return self }

        switch (result, kind) {
        case let (.success(launch), _):
            return with(launch: launch, phase: .loaded, refreshError: .some(nil))
        case let (.failure(message), .initial):
            return with(phase: .error(message: message))
        case let (.failure(message), .refresh):
            return with(refreshError: .some(message))
        }
    }

    /// Returns the new state alongside the raw generation value the caller's related-news task
    /// should be tagged with, mirroring `startingLoad()`/`startingRefresh()` for the main load.
    func startingRelatedNewsLoad() -> (state: LaunchDetailState, generation: Int) {
        let (next, value) = relatedNewsGeneration.advanced()
        return (with(relatedNewsGeneration: next), value)
    }

    /// Related news is best-effort: failures never surface an error and simply
    /// leave the section empty, since it must never block or fail the main launch load.
    ///
    /// Guarded by `relatedNewsGeneration` the same way `applyingLoadResponse` is guarded by
    /// `loadGeneration`, `Task` cancellation alone is cooperative and can't be fully trusted, so
    /// a response from a superseded related-news load (e.g. an earlier refresh's request that
    /// resolves after a newer one) must not overwrite what the newer request already applied.
    func applyingRelatedNewsResponse(_ articles: [NewsArticle], generation: Int) -> LaunchDetailState {
        guard relatedNewsGeneration.matches(generation) else { return self }
        return with(relatedArticles: articles, relatedNewsHasLoaded: true)
    }
}

// MARK: - LaunchDetailTrigger

enum LaunchDetailTrigger: Sendable {
    case onAppear
    case retry
    case refresh
}

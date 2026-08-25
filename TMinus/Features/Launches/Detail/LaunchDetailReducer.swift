//
//  LaunchDetailReducer.swift
//  TMinus
//
//  Created by Sadegh on 28/05/2026.
//

import Foundation

// MARK: - LaunchDetailAction

enum LaunchDetailAction: Sendable {
    case appear
    case retry
    case refresh
    case loadResponse(LaunchDetailLoadOutcome, kind: LoadPresentationKind, generation: Int)
    /// Starts (or restarts) the best-effort related-news load. Routed through the reducer like
    /// every other state transition here, rather than the ViewModel mutating `state` directly,
    /// so the "advance `relatedNewsGeneration` and start loading" transition is exercised by the
    /// same reducer tests as its own response (`relatedNewsResponse`), instead of living partly
    /// in the ViewModel and partly in `LaunchDetailState`.
    case startRelatedNewsLoad(fetchPolicy: FetchPolicy)
    case relatedNewsResponse([NewsArticle], generation: Int)
    /// Sent when the ViewModel cancels the in-flight main load (view disappearing) rather than it
    /// ever resolving, without this, a load cancelled mid-flight leaves `phase` stuck at
    /// `.loading` forever, since no `loadResponse` ever arrives and `.retry` only fires from
    /// `.error`. See `LaunchDetailViewModel.cancelInFlightWork`.
    case cancelled
}

/// A load either produced a launch or a user-facing failure message, never both and never
/// neither, mirrors `NewsDetailLoadOutcome`; see its doc comment for the full rationale
/// (a bespoke enum for this closed set of outcomes, matching `DetailPhase`/`ListPhase`/
/// `ListLoadKind`'s convention, rather than the stdlib `Result` or an independently-optional
/// pair that can represent an impossible "both nil" state).
enum LaunchDetailLoadOutcome: Equatable, Sendable {
    case success(Launch)
    case failure(String)
}

// MARK: - LaunchDetailEffect

enum LaunchDetailEffect: Sendable {
    case load(id: String, fetchPolicy: FetchPolicy, kind: LoadPresentationKind, generation: Int)
    case loadRelatedNews(launchID: String, fetchPolicy: FetchPolicy, generation: Int)
}

// MARK: - LaunchDetailReducer

enum LaunchDetailReducer {
    static func reduce(state: LaunchDetailState,
                       action: LaunchDetailAction) -> (state: LaunchDetailState, effect: LaunchDetailEffect?)
    {
        switch action {
        case .appear:
            guard case .idle = state.phase else {
                return (state, nil)
            }
            let (newState, generation) = state.startingLoad()
            return (newState, .load(id: newState.launchID, fetchPolicy: .useCache, kind: .initial, generation: generation))

        case .retry:
            guard case .error = state.phase else {
                return (state, nil)
            }
            let (newState, generation) = state.startingLoad()
            return (newState, .load(id: newState.launchID, fetchPolicy: .useCache, kind: .initial, generation: generation))

        case .refresh:
            guard case .loaded = state.phase else {
                return (state, nil)
            }
            let (newState, generation) = state.startingRefresh()
            return (newState, .load(id: newState.launchID, fetchPolicy: .networkOnly, kind: .refresh, generation: generation))

        case let .loadResponse(result, kind, generation):
            return (state.applyingLoadResponse(result: result, kind: kind, generation: generation), nil)

        case let .startRelatedNewsLoad(fetchPolicy):
            let (newState, generation) = state.startingRelatedNewsLoad()
            return (newState, .loadRelatedNews(launchID: newState.launchID, fetchPolicy: fetchPolicy, generation: generation))

        case let .relatedNewsResponse(articles, generation):
            return (state.applyingRelatedNewsResponse(articles, generation: generation), nil)

        case .cancelled:
            // Only `.appear`/`.retry` ever set `.loading`, `.refresh` keeps `.loaded` throughout,
            // so a refresh cancelled mid-flight needs no phase change here at all.
            guard case .loading = state.phase else {
                return (state, nil)
            }
            // Also advances `loadGeneration`, see `LaunchListReducer.cancelled` for why: the
            // main-load task only skips `send(.loadResponse(...))` if its fetch actually throws
            // `CancellationError`; a coalesced fetch that keeps running for another joiner (per
            // `InFlightRequestStore`'s doc comment) can still resolve normally afterward. Without
            // bumping the generation, that late response would pass `applyingLoadResponse`'s guard
            // and resurrect stale state, and since `.appear` only fires from `.idle`, flipping
            // phase to `.loaded` that way would permanently swallow the next `.appear`.
            let (nextGeneration, _) = state.loadGeneration.advanced()
            return (state.with(phase: .idle, loadGeneration: nextGeneration), nil)
        }
    }
}

// MARK: ReducerProtocol

extension LaunchDetailReducer: ReducerProtocol {}

//
//  NewsDetailReducer.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import Foundation

// MARK: - NewsDetailAction

enum NewsDetailAction: Sendable {
    case appear
    case retry
    case refresh
    case loadResponse(NewsDetailLoadOutcome, kind: LoadPresentationKind, generation: Int)
    /// See `LaunchDetailAction.cancelled`, sent when the ViewModel cancels the in-flight main
    /// load rather than it ever resolving, so `phase` doesn't get stuck at `.loading` forever.
    case cancelled
}

/// A load either produced an article or a user-facing failure message, never both and never
/// neither, matches this codebase's convention of a bespoke enum for closed sets of outcomes
/// (see `DetailPhase`, `ListPhase`, `ListLoadKind`) rather than reaching for the stdlib `Result`.
enum NewsDetailLoadOutcome: Equatable, Sendable {
    case success(NewsArticle)
    case failure(String)
}

// MARK: - NewsDetailEffect

enum NewsDetailEffect: Sendable {
    case load(id: String, fetchPolicy: FetchPolicy, kind: LoadPresentationKind, generation: Int)
}

// MARK: - NewsDetailReducer

enum NewsDetailReducer {
    static func reduce(state: NewsDetailState,
                       action: NewsDetailAction) -> (state: NewsDetailState, effect: NewsDetailEffect?)
    {
        switch action {
        case .appear:
            guard case .idle = state.phase else {
                return (state, nil)
            }
            let (newState, generation) = state.startingLoad()
            return (newState, .load(id: newState.articleID, fetchPolicy: .useCache, kind: .initial, generation: generation))

        case .retry:
            guard case .error = state.phase else {
                return (state, nil)
            }
            let (newState, generation) = state.startingLoad()
            return (newState, .load(id: newState.articleID, fetchPolicy: .useCache, kind: .initial, generation: generation))

        case .refresh:
            guard case .loaded = state.phase else {
                return (state, nil)
            }
            let (newState, generation) = state.startingRefresh()
            return (newState, .load(id: newState.articleID, fetchPolicy: .networkOnly, kind: .refresh, generation: generation))

        case let .loadResponse(result, kind, generation):
            return (state.applyingLoadResponse(result: result, kind: kind, generation: generation), nil)

        case .cancelled:
            guard case .loading = state.phase else {
                return (state, nil)
            }
            // See `LaunchDetailReducer.cancelled`, also advances `loadGeneration` so a late
            // response from a task that didn't observe cancellation in time can't resurrect state.
            let (nextGeneration, _) = state.loadGeneration.advanced()
            return (state.with(phase: .idle, loadGeneration: nextGeneration), nil)
        }
    }
}

// MARK: ReducerProtocol

extension NewsDetailReducer: ReducerProtocol {}

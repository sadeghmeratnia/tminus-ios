//
//  NewsDetailReducer.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import Foundation

// MARK: - NewsDetailAction

enum NewsDetailAction {
    case appear
    case retry
    case loadResponse(NewsDetailLoadOutcome, generation: Int)
}

/// A load either produced an article or a user-facing failure message, never both and never
/// neither — matches this codebase's convention of a bespoke enum for closed sets of outcomes
/// (see `DetailPhase`, `ListPhase`, `ListLoadKind`) rather than reaching for the stdlib `Result`.
enum NewsDetailLoadOutcome: Equatable {
    case success(NewsArticle)
    case failure(String)
}

// MARK: - NewsDetailEffect

enum NewsDetailEffect {
    case load(id: String, generation: Int)
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
            return (newState, .load(id: newState.articleID, generation: generation))

        case .retry:
            guard case .error = state.phase else {
                return (state, nil)
            }
            let (newState, generation) = state.startingLoad()
            return (newState, .load(id: newState.articleID, generation: generation))

        case let .loadResponse(result, generation):
            return (state.applyingLoadResponse(result: result, generation: generation), nil)
        }
    }
}

// MARK: ReducerProtocol

extension NewsDetailReducer: ReducerProtocol {}

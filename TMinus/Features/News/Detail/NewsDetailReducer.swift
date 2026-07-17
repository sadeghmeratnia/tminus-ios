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
    case loadResponse(article: NewsArticle?, errorMessage: String?, generation: Int)
}

// MARK: - NewsDetailEffect

enum NewsDetailEffect {
    case load(id: String, generation: Int)
}

// MARK: - NewsDetailReducer

enum NewsDetailReducer {
    static func reduce(state: NewsDetailState,
                       action: NewsDetailAction) -> (state: NewsDetailState, effect: NewsDetailEffect?) {
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

        case let .loadResponse(article, errorMessage, generation):
            return (state.applyingLoadResponse(article: article, errorMessage: errorMessage, generation: generation), nil)
        }
    }
}

// MARK: ReducerProtocol

extension NewsDetailReducer: ReducerProtocol { }

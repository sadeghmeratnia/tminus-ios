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
    case loadResponse(article: NewsArticle?, errorMessage: String?)
}

// MARK: - NewsDetailEffect

enum NewsDetailEffect {
    case load(id: String)
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
            return (state.startingLoad(), .load(id: state.articleID))

        case .retry:
            guard case .error = state.phase else {
                return (state, nil)
            }
            return (state.startingLoad(), .load(id: state.articleID))

        case let .loadResponse(article, errorMessage):
            return (state.applyingLoadResponse(article: article, errorMessage: errorMessage), nil)
        }
    }
}

// MARK: ReducerProtocol

extension NewsDetailReducer: ReducerProtocol { }

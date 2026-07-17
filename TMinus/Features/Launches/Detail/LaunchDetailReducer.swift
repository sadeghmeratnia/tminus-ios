//
//  LaunchDetailReducer.swift
//  TMinus
//
//  Created by Sadegh on 28/05/2026.
//

import Foundation

// MARK: - LaunchDetailAction

enum LaunchDetailAction {
    case appear
    case retry
    case loadResponse(launch: Launch?, errorMessage: String?, generation: Int)
    case relatedNewsResponse([NewsArticle])
}

// MARK: - LaunchDetailEffect

enum LaunchDetailEffect {
    case load(id: String, generation: Int)
}

// MARK: - LaunchDetailReducer

enum LaunchDetailReducer {
    static func reduce(state: LaunchDetailState,
                       action: LaunchDetailAction) -> (state: LaunchDetailState, effect: LaunchDetailEffect?) {
        switch action {
        case .appear:
            guard case .idle = state.phase else {
                return (state, nil)
            }
            let (newState, generation) = state.startingLoad()
            return (newState, .load(id: newState.launchID, generation: generation))

        case .retry:
            guard case .error = state.phase else {
                return (state, nil)
            }
            let (newState, generation) = state.startingLoad()
            return (newState, .load(id: newState.launchID, generation: generation))

        case let .loadResponse(launch, errorMessage, generation):
            return (state.applyingLoadResponse(launch: launch, errorMessage: errorMessage, generation: generation), nil)

        case let .relatedNewsResponse(articles):
            return (state.applyingRelatedNewsResponse(articles), nil)
        }
    }
}

// MARK: ReducerProtocol

extension LaunchDetailReducer: ReducerProtocol { }

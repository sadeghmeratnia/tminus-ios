//
//  NewsDetailState.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import Foundation

// MARK: - NewsDetailState

struct NewsDetailState: Equatable {
    let articleID: String
    let article: NewsArticle?
    let phase: DetailPhase
    let loadGeneration: LoadGeneration

    static func initial(articleID: String) -> NewsDetailState {
        NewsDetailState(articleID: articleID, article: nil, phase: .idle, loadGeneration: LoadGeneration())
    }

    func with(article: NewsArticle? = nil, phase: DetailPhase? = nil, loadGeneration: LoadGeneration? = nil) -> NewsDetailState {
        NewsDetailState(
            articleID: articleID,
            article: article ?? self.article,
            phase: phase ?? self.phase,
            loadGeneration: loadGeneration ?? self.loadGeneration)
    }

    /// Returns the new state alongside the raw generation value the caller's effect should tag
    /// its in-flight load with.
    func startingLoad() -> (state: NewsDetailState, generation: Int) {
        let (next, value) = loadGeneration.advanced()
        return (with(phase: .loading, loadGeneration: next), value)
    }

    func applyingLoadResponse(article: NewsArticle?, errorMessage: String?, generation: Int) -> NewsDetailState {
        guard loadGeneration.matches(generation) else { return self }

        if let errorMessage {
            return with(phase: .error(message: errorMessage))
        }

        guard let article else {
            return with(phase: .error(message: L10n.Error.Network.unknown))
        }

        return with(article: article, phase: .loaded)
    }
}

// MARK: - NewsDetailTrigger

enum NewsDetailTrigger {
    case onAppear
    case retry
}

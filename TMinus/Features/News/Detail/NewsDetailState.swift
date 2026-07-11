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

    static func initial(articleID: String) -> NewsDetailState {
        NewsDetailState(articleID: articleID, article: nil, phase: .idle)
    }

    func with(article: NewsArticle? = nil, phase: DetailPhase? = nil) -> NewsDetailState {
        NewsDetailState(
            articleID: articleID,
            article: article ?? self.article,
            phase: phase ?? self.phase)
    }

    func startingLoad() -> NewsDetailState {
        with(phase: .loading)
    }

    func applyingLoadResponse(article: NewsArticle?, errorMessage: String?) -> NewsDetailState {
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

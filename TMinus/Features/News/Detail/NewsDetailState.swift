//
//  NewsDetailState.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import Foundation

// MARK: - NewsDetailState

struct NewsDetailState: Equatable, Sendable {
    let articleID: String
    let article: NewsArticle?
    let phase: DetailPhase
    let loadGeneration: LoadGeneration
    /// Non-nil only when a refresh failed but the previously-loaded article is still on screen,
    /// mirrors how `ListPagination.loadMoreError` sits beside `ListPhase` rather than inside it,
    /// so a transient advisory never needs to be smuggled into a case that's meant to mean one
    /// thing.
    let refreshError: String?

    static func initial(articleID: String) -> NewsDetailState {
        NewsDetailState(articleID: articleID, article: nil, phase: .idle, loadGeneration: LoadGeneration(), refreshError: nil)
    }

    func with(article: NewsArticle? = nil,
              phase: DetailPhase? = nil,
              loadGeneration: LoadGeneration? = nil,
              refreshError: String?? = nil) -> NewsDetailState
    {
        NewsDetailState(
            articleID: articleID,
            article: article ?? self.article,
            phase: phase ?? self.phase,
            loadGeneration: loadGeneration ?? self.loadGeneration,
            refreshError: refreshError ?? self.refreshError
        )
    }

    /// Returns the new state alongside the raw generation value the caller's effect should tag
    /// its in-flight load with.
    func startingLoad() -> (state: NewsDetailState, generation: Int) {
        let (next, value) = loadGeneration.advanced()
        return (with(phase: .loading, loadGeneration: next, refreshError: .some(nil)), value)
    }

    /// Only valid once content is already on screen, keeps `phase` at `.loaded` and the current
    /// `article` visible for the duration of the refresh, rather than replacing them with a
    /// spinner the way a first load does.
    func startingRefresh() -> (state: NewsDetailState, generation: Int) {
        let (next, value) = loadGeneration.advanced()
        return (with(loadGeneration: next, refreshError: .some(nil)), value)
    }

    func applyingLoadResponse(result: NewsDetailLoadOutcome, kind: LoadPresentationKind, generation: Int) -> NewsDetailState {
        guard loadGeneration.matches(generation) else { return self }

        switch (result, kind) {
        case let (.success(article), _):
            return with(article: article, phase: .loaded, refreshError: .some(nil))
        case let (.failure(message), .initial):
            return with(phase: .error(message: message))
        case let (.failure(message), .refresh):
            return with(refreshError: .some(message))
        }
    }
}

// MARK: - NewsDetailTrigger

enum NewsDetailTrigger: Sendable {
    case onAppear
    case retry
    case refresh
}

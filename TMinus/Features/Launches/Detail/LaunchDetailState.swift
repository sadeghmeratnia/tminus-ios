//
//  LaunchDetailState.swift
//  TMinus
//
//  Created by Sadegh on 28/05/2026.
//

import Foundation

// MARK: - LaunchDetailState

struct LaunchDetailState: Equatable {
    let launchID: String
    let launch: Launch?
    let phase: DetailPhase
    let relatedArticles: [NewsArticle]

    static func initial(launchID: String) -> LaunchDetailState {
        LaunchDetailState(launchID: launchID, launch: nil, phase: .idle, relatedArticles: [])
    }

    func with(launch: Launch? = nil,
              phase: DetailPhase? = nil,
              relatedArticles: [NewsArticle]? = nil) -> LaunchDetailState {
        LaunchDetailState(
            launchID: launchID,
            launch: launch ?? self.launch,
            phase: phase ?? self.phase,
            relatedArticles: relatedArticles ?? self.relatedArticles)
    }

    func startingLoad() -> LaunchDetailState {
        with(phase: .loading)
    }

    func applyingLoadResponse(launch: Launch?, errorMessage: String?) -> LaunchDetailState {
        if let errorMessage {
            return with(phase: .error(message: errorMessage))
        }

        guard let launch else {
            return with(phase: .error(message: L10n.Error.Network.unknown))
        }

        return with(launch: launch, phase: .loaded)
    }

    /// Related news is best-effort: failures never surface an error and simply
    /// leave the section empty, since it must never block or fail the main launch load.
    func applyingRelatedNewsResponse(_ articles: [NewsArticle]) -> LaunchDetailState {
        with(relatedArticles: articles)
    }
}

// MARK: - LaunchDetailTrigger

enum LaunchDetailTrigger {
    case onAppear
    case retry
}

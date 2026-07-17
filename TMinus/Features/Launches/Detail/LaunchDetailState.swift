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
    let loadGeneration: LoadGeneration

    static func initial(launchID: String) -> LaunchDetailState {
        LaunchDetailState(launchID: launchID, launch: nil, phase: .idle, relatedArticles: [], loadGeneration: LoadGeneration())
    }

    func with(launch: Launch? = nil,
              phase: DetailPhase? = nil,
              relatedArticles: [NewsArticle]? = nil,
              loadGeneration: LoadGeneration? = nil) -> LaunchDetailState
    {
        LaunchDetailState(
            launchID: launchID,
            launch: launch ?? self.launch,
            phase: phase ?? self.phase,
            relatedArticles: relatedArticles ?? self.relatedArticles,
            loadGeneration: loadGeneration ?? self.loadGeneration
        )
    }

    /// Returns the new state alongside the raw generation value the caller's effect should tag
    /// its in-flight load with.
    func startingLoad() -> (state: LaunchDetailState, generation: Int) {
        let (next, value) = loadGeneration.advanced()
        return (with(phase: .loading, loadGeneration: next), value)
    }

    func applyingLoadResponse(launch: Launch?, errorMessage: String?, generation: Int) -> LaunchDetailState {
        guard loadGeneration.matches(generation) else { return self }

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

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
    let phase: Phase

    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case error(message: String)
    }

    static func initial(launchID: String) -> LaunchDetailState {
        LaunchDetailState(launchID: launchID, launch: nil, phase: .idle)
    }

    func with(launch: Launch? = nil, phase: Phase? = nil) -> LaunchDetailState {
        LaunchDetailState(
            launchID: launchID,
            launch: launch ?? self.launch,
            phase: phase ?? self.phase)
    }

    func startingLoad() -> LaunchDetailState {
        with(phase: .loading)
    }

    func applyingLoadResponse(launch: Launch?, errorMessage: String?) -> LaunchDetailState {
        if let errorMessage {
            return with(phase: .error(message: errorMessage))
        }

        guard let launch else {
            return with(phase: .error(message: errorMessage ?? "Unknown error"))
        }

        return with(launch: launch, phase: .loaded)
    }
}

// MARK: - LaunchDetailTrigger

enum LaunchDetailTrigger {
    case onAppear
    case retry
}

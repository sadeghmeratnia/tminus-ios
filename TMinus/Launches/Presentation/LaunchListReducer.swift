//
//  LaunchListReducer.swift
//  TMinus
//
//  Created by Sadegh on 07/05/2026.
//

import Foundation

// MARK: - LaunchListAction

enum LaunchListAction {
    case appear
    case refresh
    case modeChanged(LaunchListMode)
    case loadResponse(
        mode: LaunchListMode,
        previousLaunches: [Launch],
        launches: [Launch],
        errorMessage: String?)
}

// MARK: - LaunchListEffect

enum LaunchListEffect {
    case load(mode: LaunchListMode, previousLaunches: [Launch])
}

// MARK: - LaunchListReducer

enum LaunchListReducer {
    static func reduce(state: LaunchListState,
                       action: LaunchListAction) -> (state: LaunchListState, effect: LaunchListEffect?) {
        switch action {
        case .appear:
            let mode = state.mode
            let previousLaunches: [Launch] = []
            return (
                .loading(mode: mode, launches: previousLaunches),
                .load(mode: mode, previousLaunches: previousLaunches))

        case .refresh:
            let mode = state.mode
            let previousLaunches = state.launches
            return (
                .loading(mode: mode, launches: previousLaunches),
                .load(mode: mode, previousLaunches: previousLaunches))

        case let .modeChanged(newMode):
            guard newMode != state.mode else {
                return (state, nil)
            }
            let previousLaunches: [Launch] = []
            return (
                .loading(mode: newMode, launches: previousLaunches),
                .load(mode: newMode, previousLaunches: previousLaunches))

        case let .loadResponse(mode, previousLaunches, launches, errorMessage):
            if let errorMessage {
                return (.error(mode: mode, message: errorMessage, launches: previousLaunches), nil)
            }
            return (.loaded(mode: mode, launches: launches), nil)
        }
    }
}

// MARK: ReducerProtocol

extension LaunchListReducer: ReducerProtocol { }

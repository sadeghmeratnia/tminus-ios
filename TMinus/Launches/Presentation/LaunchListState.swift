//
//  LaunchListState.swift
//  TMinus
//
//  Created by Sadegh on 07/05/2026.
//

import Foundation

// MARK: - LaunchListMode

enum LaunchListMode: String, CaseIterable, Identifiable {
    case upcoming
    case previous

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .upcoming:
            return L10n.Launches.Mode.upcoming
        case .previous:
            return L10n.Launches.Mode.previous
        }
    }
}

// MARK: - LaunchListState

enum LaunchListState {
    case idle(mode: LaunchListMode)
    case loading(mode: LaunchListMode, launches: [Launch])
    case loaded(mode: LaunchListMode, launches: [Launch])
    case error(mode: LaunchListMode, message: String, launches: [Launch])
}

// MARK: - LaunchListTrigger

enum LaunchListTrigger {
    case onAppear
    case refresh
    case modeChanged(LaunchListMode)
}

extension LaunchListState {
    var mode: LaunchListMode {
        switch self {
        case let .idle(mode),
             let .loading(mode, _),
             let .loaded(mode, _),
             let .error(mode, _, _):
            return mode
        }
    }

    var launches: [Launch] {
        switch self {
        case .idle:
            return []
        case let .loading(_, launches),
             let .loaded(_, launches),
             let .error(_, _, launches):
            return launches
        }
    }
}

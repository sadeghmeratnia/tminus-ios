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

struct LaunchListPagination: Equatable {
    let currentPage: Int
    let nextPage: Int?
    let previousPage: Int?
    let totalCount: Int?
    let isLoadingMore: Bool
    let loadMoreError: String?

    static let initial = LaunchListPagination(
        currentPage: 1,
        nextPage: nil,
        previousPage: nil,
        totalCount: nil,
        isLoadingMore: false,
        loadMoreError: nil)
}

enum LaunchListState {
    case idle(mode: LaunchListMode)
    case loading(mode: LaunchListMode, launches: [Launch], pagination: LaunchListPagination)
    case loaded(mode: LaunchListMode, launches: [Launch], pagination: LaunchListPagination)
    case error(mode: LaunchListMode, message: String, launches: [Launch], pagination: LaunchListPagination)
}

// MARK: - LaunchListTrigger

enum LaunchListTrigger {
    case onAppear
    case refresh
    case modeChanged(LaunchListMode)
    case launchAppeared(String)
    case retryLoadMore
}

extension LaunchListState {
    var mode: LaunchListMode {
        switch self {
        case let .idle(mode),
             let .loading(mode, _, _),
             let .loaded(mode, _, _),
             let .error(mode, _, _, _):
            return mode
        }
    }

    var launches: [Launch] {
        switch self {
        case .idle:
            return []
        case let .loading(_, launches, _),
             let .loaded(_, launches, _),
             let .error(_, _, launches, _):
            return launches
        }
    }

    var pagination: LaunchListPagination {
        switch self {
        case .idle:
            return .initial
        case let .loading(_, _, pagination),
             let .loaded(_, _, pagination),
             let .error(_, _, _, pagination):
            return pagination
        }
    }
}

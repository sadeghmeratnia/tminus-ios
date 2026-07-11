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

struct LaunchListState: Equatable {
    let mode: LaunchListMode
    let launches: [Launch]
    let pagination: ListPagination
    let phase: ListPhase

    static let initial = LaunchListState(
        mode: .upcoming,
        launches: [],
        pagination: .initial,
        phase: .idle)

    func with(mode: LaunchListMode? = nil,
              launches: [Launch]? = nil,
              pagination: ListPagination? = nil,
              phase: ListPhase? = nil) -> LaunchListState {
        LaunchListState(
            mode: mode ?? self.mode,
            launches: launches ?? self.launches,
            pagination: pagination ?? self.pagination,
            phase: phase ?? self.phase)
    }

    func startingInitialLoad() -> LaunchListState {
        with(launches: [], pagination: .initial, phase: .loading(.initial))
    }

    func startingRefresh() -> LaunchListState {
        with(phase: .loading(.refresh))
    }

    func startingModeChange(_ newMode: LaunchListMode) -> LaunchListState {
        with(mode: newMode, launches: [], pagination: .initial, phase: .loading(.initial))
    }

    func startingLoadMore() -> LaunchListState {
        with(pagination: pagination.clearingLoadMoreError(), phase: .loading(.loadMore))
    }

    func applyingLoadResponse(mode: LaunchListMode,
                              previousLaunches: [Launch],
                              page: PagedResult<Launch>,
                              kind: ListLoadKind,
                              errorMessage: String?) -> LaunchListState {
        if let errorMessage {
            if kind == .loadMore {
                return with(
                    mode: mode,
                    launches: previousLaunches,
                    pagination: pagination.failingLoadMore(message: errorMessage),
                    phase: .loaded)
            }

            return with(
                mode: mode,
                launches: previousLaunches,
                pagination: pagination.clearingLoadMoreError(),
                phase: .error(message: errorMessage))
        }

        let launches = kind == .loadMore ? previousLaunches.merging(page.items) : page.items
        return with(
            mode: mode,
            launches: launches,
            pagination: pagination.applying(page: page),
            phase: .loaded)
    }
}

// MARK: - LaunchListTrigger

enum LaunchListTrigger {
    case onAppear
    case refresh
    case modeChanged(LaunchListMode)
    case launchAppeared(String)
    case retryLoadMore
}

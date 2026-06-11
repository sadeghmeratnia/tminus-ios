//
//  LaunchListReducer.swift
//  TMinus
//
//  Created by Sadegh on 07/05/2026.
//

import Foundation

// MARK: - LaunchListLoadKind

/// The two kinds of load the screen can run concurrently.
/// Also identifies the running task of each kind in the ViewModel.
enum LaunchListLoadKind: Hashable {
    /// Initial load, refresh, or mode change — replaces the list from page 1.
    case fresh
    /// Pagination — appends the next page to the current list.
    case loadMore

    /// A fresh load invalidates any pending load-more, but a load-more
    /// must never cancel an in-flight fresh load.
    var cancels: Set<LaunchListLoadKind> {
        switch self {
        case .fresh:
            return [.fresh, .loadMore]
        case .loadMore:
            return [.loadMore]
        }
    }
}

// MARK: - LaunchListAction

enum LaunchListAction {
    case appear
    case refresh
    case modeChanged(LaunchListMode)
    case loadMore
    case retryLoadMore
    case loadResponse(
        mode: LaunchListMode,
        previousLaunches: [Launch],
        page: PagedResult<Launch>,
        kind: LaunchListLoadKind,
        errorMessage: String?)
}

// MARK: - LaunchListEffect

enum LaunchListEffect {
    case load(
        mode: LaunchListMode,
        page: Int,
        previousLaunches: [Launch],
        fetchPolicy: LaunchFetchPolicy,
        kind: LaunchListLoadKind)
}

// MARK: - LaunchListReducer

enum LaunchListReducer {
    static func reduce(state: LaunchListState,
                       action: LaunchListAction) -> (state: LaunchListState, effect: LaunchListEffect?) {
        switch action {
        case .appear:
            return (
                state.startingInitialLoad(),
                loadEffect(
                    mode: state.mode,
                    page: 1,
                    previousLaunches: [],
                    fetchPolicy: .useCache,
                    kind: .fresh))

        case .refresh:
            return (
                state.startingRefresh(),
                loadEffect(
                    mode: state.mode,
                    page: 1,
                    previousLaunches: state.launches,
                    fetchPolicy: .networkOnly,
                    kind: .fresh))

        case let .modeChanged(newMode):
            guard newMode != state.mode else {
                return (state, nil)
            }
            return (
                state.startingModeChange(newMode),
                loadEffect(
                    mode: newMode,
                    page: 1,
                    previousLaunches: [],
                    fetchPolicy: .useCache,
                    kind: .fresh))

        case .retryLoadMore:
            guard state.pagination.loadMoreError != nil,
                  let nextPage = state.pagination.nextPage else {
                return (state, nil)
            }
            return (
                state.startingLoadMore(),
                loadEffect(
                    mode: state.mode,
                    page: nextPage,
                    previousLaunches: state.launches,
                    fetchPolicy: .networkOnly,
                    kind: .loadMore))

        case .loadMore:
            guard case .loaded = state.phase,
                  state.pagination.loadMoreError == nil,
                  let nextPage = state.pagination.nextPage,
                  state.launches.isEmpty == false else {
                return (state, nil)
            }
            return (
                state.startingLoadMore(),
                loadEffect(
                    mode: state.mode,
                    page: nextPage,
                    previousLaunches: state.launches,
                    fetchPolicy: .networkOnly,
                    kind: .loadMore))

        case let .loadResponse(mode, previousLaunches, page, kind, errorMessage):
            return (
                state.applyingLoadResponse(
                    mode: mode,
                    previousLaunches: previousLaunches,
                    page: page,
                    kind: kind,
                    errorMessage: errorMessage),
                nil)
        }
    }

    private static func loadEffect(mode: LaunchListMode,
                                   page: Int,
                                   previousLaunches: [Launch],
                                   fetchPolicy: LaunchFetchPolicy,
                                   kind: LaunchListLoadKind) -> LaunchListEffect {
        .load(
            mode: mode,
            page: page,
            previousLaunches: previousLaunches,
            fetchPolicy: fetchPolicy,
            kind: kind)
    }
}

// MARK: ReducerProtocol

extension LaunchListReducer: ReducerProtocol { }

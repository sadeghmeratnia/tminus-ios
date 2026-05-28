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
    case loadMore
    case retryLoadMore
    case loadResponse(
        mode: LaunchListMode,
        previousLaunches: [Launch],
        page: PagedResult<Launch>,
        isLoadMore: Bool,
        errorMessage: String?)
}

// MARK: - LaunchListEffect

enum LaunchListEffect {
    case load(
        mode: LaunchListMode,
        page: Int,
        previousLaunches: [Launch],
        fetchPolicy: LaunchFetchPolicy,
        isLoadMore: Bool)
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
                    isLoadMore: false))

        case .refresh:
            return (
                state.startingRefresh(),
                loadEffect(
                    mode: state.mode,
                    page: 1,
                    previousLaunches: state.launches,
                    fetchPolicy: .networkOnly,
                    isLoadMore: false))

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
                    isLoadMore: false))

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
                    isLoadMore: true))

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
                    isLoadMore: true))

        case let .loadResponse(mode, previousLaunches, page, isLoadMore, errorMessage):
            return (
                state.applyingLoadResponse(
                    mode: mode,
                    previousLaunches: previousLaunches,
                    page: page,
                    isLoadMore: isLoadMore,
                    errorMessage: errorMessage),
                nil)
        }
    }

    private static func loadEffect(mode: LaunchListMode,
                                   page: Int,
                                   previousLaunches: [Launch],
                                   fetchPolicy: LaunchFetchPolicy,
                                   isLoadMore: Bool) -> LaunchListEffect {
        .load(
            mode: mode,
            page: page,
            previousLaunches: previousLaunches,
            fetchPolicy: fetchPolicy,
            isLoadMore: isLoadMore)
    }
}

// MARK: ReducerProtocol

extension LaunchListReducer: ReducerProtocol { }

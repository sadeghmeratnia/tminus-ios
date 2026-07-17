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
        kind: ListLoadKind,
        errorMessage: String?,
        generation: Int)
}

// MARK: - LaunchListEffect

enum LaunchListEffect {
    case load(
        mode: LaunchListMode,
        page: Int,
        previousLaunches: [Launch],
        fetchPolicy: FetchPolicy,
        kind: ListLoadKind,
        generation: Int)
}

// MARK: - LaunchListReducer

enum LaunchListReducer {
    static func reduce(state: LaunchListState,
                       action: LaunchListAction) -> (state: LaunchListState, effect: LaunchListEffect?) {
        switch action {
        case .appear:
            let (nextState, generation) = state.startingInitialLoad()
            return (
                nextState,
                loadEffect(
                    mode: state.mode,
                    page: 1,
                    previousLaunches: [],
                    fetchPolicy: .useCache,
                    kind: .fresh,
                    generation: generation))

        case .refresh:
            let (nextState, generation) = state.startingRefresh()
            return (
                nextState,
                loadEffect(
                    mode: state.mode,
                    page: 1,
                    previousLaunches: state.launches,
                    fetchPolicy: .networkOnly,
                    kind: .fresh,
                    generation: generation))

        case let .modeChanged(newMode):
            guard newMode != state.mode else {
                return (state, nil)
            }
            let (nextState, generation) = state.startingModeChange(newMode)
            return (
                nextState,
                loadEffect(
                    mode: newMode,
                    page: 1,
                    previousLaunches: [],
                    fetchPolicy: .useCache,
                    kind: .fresh,
                    generation: generation))

        case .retryLoadMore:
            guard state.pagination.loadMoreError != nil,
                  let nextPage = state.pagination.nextPage else {
                return (state, nil)
            }
            let (nextState, generation) = state.startingLoadMore()
            return (
                nextState,
                loadEffect(
                    mode: state.mode,
                    page: nextPage,
                    previousLaunches: state.launches,
                    fetchPolicy: .networkOnly,
                    kind: .loadMore,
                    generation: generation))

        case .loadMore:
            guard case .loaded = state.phase,
                  state.pagination.loadMoreError == nil,
                  let nextPage = state.pagination.nextPage,
                  state.launches.isEmpty == false else {
                return (state, nil)
            }
            let (nextState, generation) = state.startingLoadMore()
            return (
                nextState,
                loadEffect(
                    mode: state.mode,
                    page: nextPage,
                    previousLaunches: state.launches,
                    fetchPolicy: .networkOnly,
                    kind: .loadMore,
                    generation: generation))

        case let .loadResponse(mode, previousLaunches, page, kind, errorMessage, generation):
            return (
                state.applyingLoadResponse(
                    mode: mode,
                    previousLaunches: previousLaunches,
                    page: page,
                    kind: kind,
                    errorMessage: errorMessage,
                    generation: generation),
                nil)
        }
    }

    private static func loadEffect(mode: LaunchListMode,
                                   page: Int,
                                   previousLaunches: [Launch],
                                   fetchPolicy: FetchPolicy,
                                   kind: ListLoadKind,
                                   generation: Int) -> LaunchListEffect {
        .load(
            mode: mode,
            page: page,
            previousLaunches: previousLaunches,
            fetchPolicy: fetchPolicy,
            kind: kind,
            generation: generation)
    }
}

// MARK: ReducerProtocol

extension LaunchListReducer: ReducerProtocol { }

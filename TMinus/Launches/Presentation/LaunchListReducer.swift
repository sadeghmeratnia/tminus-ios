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
    case load(mode: LaunchListMode,
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
            let mode = state.mode
            let previousLaunches: [Launch] = []
            return (
                .loading(mode: mode, launches: previousLaunches, pagination: .initial),
                .load(mode: mode, page: 1, previousLaunches: previousLaunches, fetchPolicy: .useCache, isLoadMore: false))

        case .refresh:
            let mode = state.mode
            let previousLaunches = state.launches
            return (
                .loading(mode: mode, launches: previousLaunches, pagination: state.pagination),
                .load(mode: mode, page: 1, previousLaunches: previousLaunches, fetchPolicy: .networkOnly, isLoadMore: false))

        case let .modeChanged(newMode):
            guard newMode != state.mode else {
                return (state, nil)
            }
            let previousLaunches: [Launch] = []
            return (
                .loading(mode: newMode, launches: previousLaunches, pagination: .initial),
                .load(mode: newMode, page: 1, previousLaunches: previousLaunches, fetchPolicy: .useCache, isLoadMore: false))

        case .retryLoadMore:
            guard state.pagination.loadMoreError != nil,
                  let nextPage = state.pagination.nextPage else {
                return (state, nil)
            }
            let retryPagination = LaunchListPagination(
                currentPage: state.pagination.currentPage,
                nextPage: nextPage,
                previousPage: state.pagination.previousPage,
                totalCount: state.pagination.totalCount,
                isLoadingMore: true,
                loadMoreError: nil)
            return (
                .loading(mode: state.mode, launches: state.launches, pagination: retryPagination),
                .load(
                    mode: state.mode,
                    page: nextPage,
                    previousLaunches: state.launches,
                    fetchPolicy: .networkOnly,
                    isLoadMore: true))

        case .loadMore:
            guard state.pagination.isLoadingMore == false,
                  state.pagination.loadMoreError == nil,
                  let nextPage = state.pagination.nextPage,
                  state.launches.isEmpty == false else {
                return (state, nil)
            }
            let pagination = LaunchListPagination(
                currentPage: state.pagination.currentPage,
                nextPage: state.pagination.nextPage,
                previousPage: state.pagination.previousPage,
                totalCount: state.pagination.totalCount,
                isLoadingMore: true,
                loadMoreError: nil)
            return (
                .loading(mode: state.mode, launches: state.launches, pagination: pagination),
                .load(
                    mode: state.mode,
                    page: nextPage,
                    previousLaunches: state.launches,
                    fetchPolicy: .networkOnly,
                    isLoadMore: true))

        case let .loadResponse(mode, previousLaunches, page, isLoadMore, errorMessage):
            let pagination = LaunchListPagination(
                currentPage: page.currentPage,
                nextPage: page.nextPage,
                previousPage: page.previousPage,
                totalCount: page.totalCount,
                isLoadingMore: false,
                loadMoreError: nil)

            if let errorMessage {
                if isLoadMore {
                    let errorPagination = LaunchListPagination(
                        currentPage: state.pagination.currentPage,
                        nextPage: state.pagination.nextPage,
                        previousPage: state.pagination.previousPage,
                        totalCount: state.pagination.totalCount,
                        isLoadingMore: false,
                        loadMoreError: errorMessage)
                    return (.loaded(mode: mode, launches: previousLaunches, pagination: errorPagination), nil)
                }
                let fallbackPagination = LaunchListPagination(
                    currentPage: state.pagination.currentPage,
                    nextPage: state.pagination.nextPage,
                    previousPage: state.pagination.previousPage,
                    totalCount: state.pagination.totalCount,
                    isLoadingMore: false,
                    loadMoreError: nil)
                return (.error(mode: mode, message: errorMessage, launches: previousLaunches, pagination: fallbackPagination), nil)
            }

            if isLoadMore {
                let mergedLaunches = mergeLaunches(previousLaunches, page.items)
                return (.loaded(mode: mode, launches: mergedLaunches, pagination: pagination), nil)
            }

            return (.loaded(mode: mode, launches: page.items, pagination: pagination), nil)
        }
    }

    private static func mergeLaunches(_ existing: [Launch], _ incoming: [Launch]) -> [Launch] {
        var ids = Set(existing.map(\.id))
        var merged = existing
        for launch in incoming where ids.contains(launch.id) == false {
            merged.append(launch)
            ids.insert(launch.id)
        }
        return merged
    }
}

// MARK: ReducerProtocol

extension LaunchListReducer: ReducerProtocol { }

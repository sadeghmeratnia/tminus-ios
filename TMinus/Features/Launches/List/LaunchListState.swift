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

// MARK: - LaunchListPagination

struct LaunchListPagination: Equatable {
    let currentPage: Int
    let nextPage: Int?
    let previousPage: Int?
    let totalCount: Int?
    let loadMoreError: String?

    static let initial = LaunchListPagination(
        currentPage: 1,
        nextPage: nil,
        previousPage: nil,
        totalCount: nil,
        loadMoreError: nil)

    func with(currentPage: Int? = nil,
              nextPage: Int? = nil,
              previousPage: Int? = nil,
              totalCount: Int? = nil,
              loadMoreError: String? = nil,
              clearsLoadMoreError: Bool = false) -> LaunchListPagination {
        LaunchListPagination(
            currentPage: currentPage ?? self.currentPage,
            nextPage: nextPage ?? self.nextPage,
            previousPage: previousPage ?? self.previousPage,
            totalCount: totalCount ?? self.totalCount,
            loadMoreError: clearsLoadMoreError ? nil : (loadMoreError ?? self.loadMoreError))
    }

    func applying(page: PagedResult<Launch>) -> LaunchListPagination {
        with(
            currentPage: page.currentPage,
            nextPage: page.nextPage,
            previousPage: page.previousPage,
            totalCount: page.totalCount,
            loadMoreError: nil,
            clearsLoadMoreError: true)
    }

    func failingLoadMore(message: String) -> LaunchListPagination {
        with(loadMoreError: message)
    }

    func clearingLoadMoreError() -> LaunchListPagination {
        with(loadMoreError: nil, clearsLoadMoreError: true)
    }
}

// MARK: - LaunchListState

struct LaunchListState: Equatable {
    let mode: LaunchListMode
    let launches: [Launch]
    let pagination: LaunchListPagination
    let phase: Phase

    enum Phase: Equatable {
        case idle
        case loading(LoadingKind)
        case loaded
        case error(message: String)

        enum LoadingKind: Equatable {
            case initial
            case refresh
            case loadMore
        }
    }

    static let initial = LaunchListState(
        mode: .upcoming,
        launches: [],
        pagination: .initial,
        phase: .idle)

    func with(mode: LaunchListMode? = nil,
              launches: [Launch]? = nil,
              pagination: LaunchListPagination? = nil,
              phase: Phase? = nil) -> LaunchListState {
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
                              kind: LaunchListLoadKind,
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

        let launches = kind == .loadMore ? Self.mergeLaunches(previousLaunches, page.items) : page.items
        return with(
            mode: mode,
            launches: launches,
            pagination: pagination.applying(page: page),
            phase: .loaded)
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

// MARK: - LaunchListTrigger

enum LaunchListTrigger {
    case onAppear
    case refresh
    case modeChanged(LaunchListMode)
    case launchAppeared(String)
    case retryLoadMore
}

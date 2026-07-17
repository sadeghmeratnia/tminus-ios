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
    let loadGenerations: ListLoadGenerations

    init(mode: LaunchListMode,
         launches: [Launch],
         pagination: ListPagination,
         phase: ListPhase,
         loadGenerations: ListLoadGenerations = ListLoadGenerations()) {
        self.mode = mode
        self.launches = launches
        self.pagination = pagination
        self.phase = phase
        self.loadGenerations = loadGenerations
    }

    static let initial = LaunchListState(
        mode: .upcoming,
        launches: [],
        pagination: .initial,
        phase: .idle)

    func with(mode: LaunchListMode? = nil,
              launches: [Launch]? = nil,
              pagination: ListPagination? = nil,
              phase: ListPhase? = nil,
              loadGenerations: ListLoadGenerations? = nil) -> LaunchListState {
        LaunchListState(
            mode: mode ?? self.mode,
            launches: launches ?? self.launches,
            pagination: pagination ?? self.pagination,
            phase: phase ?? self.phase,
            loadGenerations: loadGenerations ?? self.loadGenerations)
    }

    /// Every start-of-load method advances the generation for the relevant `ListLoadKind` and
    /// hands back the raw value the caller's effect must tag its in-flight work with — this
    /// guards against a superseded load clobbering state, even if task cancellation ever fails
    /// to prevent that response from arriving. Mirrors the `LoadGeneration` pattern already used
    /// by detail screens, via the per-kind `ListLoadGenerations`.
    func startingInitialLoad() -> (state: LaunchListState, generation: Int) {
        let (next, value) = loadGenerations.advancing(for: .fresh)
        return (with(launches: [], pagination: .initial, phase: .loading(.initial), loadGenerations: next), value)
    }

    func startingRefresh() -> (state: LaunchListState, generation: Int) {
        let (next, value) = loadGenerations.advancing(for: .fresh)
        return (with(phase: .loading(.refresh), loadGenerations: next), value)
    }

    func startingModeChange(_ newMode: LaunchListMode) -> (state: LaunchListState, generation: Int) {
        let (next, value) = loadGenerations.advancing(for: .fresh)
        return (
            with(mode: newMode, launches: [], pagination: .initial, phase: .loading(.initial), loadGenerations: next),
            value)
    }

    func startingLoadMore() -> (state: LaunchListState, generation: Int) {
        let (next, value) = loadGenerations.advancing(for: .loadMore)
        return (
            with(pagination: pagination.clearingLoadMoreError(), phase: .loading(.loadMore), loadGenerations: next),
            value)
    }

    func applyingLoadResponse(mode: LaunchListMode,
                              previousLaunches: [Launch],
                              page: PagedResult<Launch>,
                              kind: ListLoadKind,
                              errorMessage: String?,
                              generation: Int) -> LaunchListState {
        guard loadGenerations.matches(generation, for: kind) else { return self }

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

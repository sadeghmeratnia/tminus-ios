//
//  LaunchListState.swift
//  TMinus
//
//  Created by Sadegh on 07/05/2026.
//

import Foundation

// MARK: - LaunchListMode

enum LaunchListMode: String, CaseIterable, Identifiable, Sendable {
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

struct LaunchListState: Equatable, Sendable {
    let mode: LaunchListMode
    let launches: [Launch]
    let searchText: String
    let pagination: ListPagination
    let phase: ListPhase
    let loadGenerations: ListLoadGenerations

    init(mode: LaunchListMode,
         launches: [Launch],
         searchText: String = "",
         pagination: ListPagination,
         phase: ListPhase,
         loadGenerations: ListLoadGenerations = ListLoadGenerations())
    {
        self.mode = mode
        self.launches = launches
        self.searchText = searchText
        self.pagination = pagination
        self.phase = phase
        self.loadGenerations = loadGenerations
    }

    static let initial = LaunchListState(
        mode: .upcoming,
        launches: [],
        pagination: .initial,
        phase: .idle
    )

    func with(mode: LaunchListMode? = nil,
              launches: [Launch]? = nil,
              searchText: String? = nil,
              pagination: ListPagination? = nil,
              phase: ListPhase? = nil,
              loadGenerations: ListLoadGenerations? = nil) -> LaunchListState
    {
        LaunchListState(
            mode: mode ?? self.mode,
            launches: launches ?? self.launches,
            searchText: searchText ?? self.searchText,
            pagination: pagination ?? self.pagination,
            phase: phase ?? self.phase,
            loadGenerations: loadGenerations ?? self.loadGenerations
        )
    }

    /// Every start-of-load method advances the generation for the relevant `ListLoadKind` and
    /// hands back the raw value the caller's effect must tag its in-flight work with, this
    /// guards against a superseded load clobbering state, even if task cancellation ever fails
    /// to prevent that response from arriving. Mirrors the `LoadGeneration` pattern already used
    /// by detail screens, via the per-kind `ListLoadGenerations`.
    func startingInitialLoad() -> (state: LaunchListState, generation: Int) {
        let (next, value) = loadGenerations.advancing(for: .fresh)
        return (with(launches: [], pagination: .initial, phase: .loading(.initial), loadGenerations: next), value)
    }

    func startingRefresh() -> (state: LaunchListState, generation: Int) {
        let (next, value) = loadGenerations.advancing(for: .fresh)
        return (
            with(pagination: pagination.clearingLoadMoreError(), phase: .loading(.refresh), loadGenerations: next),
            value
        )
    }

    /// Keeps `searchText` as-is, switching tabs doesn't clear an in-progress search, it just
    /// reloads the new tab's results filtered by whatever search is already active.
    func startingModeChange(_ newMode: LaunchListMode) -> (state: LaunchListState, generation: Int) {
        let (next, value) = loadGenerations.advancing(for: .fresh)
        return (
            with(mode: newMode, launches: [], pagination: .initial, phase: .loading(.initial), loadGenerations: next),
            value
        )
    }

    /// See `NewsListState`'s equivalent methods, same debounced-search rationale, shared pattern
    /// rather than reimplemented per feature.
    func startingSearch(_ text: String) -> (state: LaunchListState, generation: Int) {
        let (next, value) = loadGenerations.advancing(for: .fresh)
        return (
            with(launches: [], searchText: text, pagination: .initial, phase: .loading(.initial), loadGenerations: next),
            value
        )
    }

    /// Also clears a stale `loadMoreError`, it belongs to the load-more footer of the
    /// pre-edit results, and leaving it in place would show that footer error for the full
    /// debounce window even though a fresh search (which replaces the list entirely) is about
    /// to supersede it.
    func updatingSearchText(_ text: String) -> LaunchListState {
        with(searchText: text, pagination: pagination.clearingLoadMoreError())
    }

    func startingLoadMore() -> (state: LaunchListState, generation: Int) {
        let (next, value) = loadGenerations.advancing(for: .loadMore)
        return (
            with(pagination: pagination.clearingLoadMoreError(), phase: .loading(.loadMore), loadGenerations: next),
            value
        )
    }

    func applyingLoadResponse(mode: LaunchListMode,
                              searchText: String,
                              previousLaunches: [Launch],
                              page: PagedResult<Launch>,
                              kind: ListLoadKind,
                              errorPresentation: LoadPresentationKind,
                              errorMessage: String?,
                              generation: Int) -> LaunchListState
    {
        guard mode == self.mode,
              searchText == self.searchText,
              loadGenerations.matches(generation, for: kind)
        else { return self }

        if let errorMessage {
            if kind == .loadMore {
                return with(
                    launches: previousLaunches,
                    pagination: pagination.failingLoadMore(message: errorMessage),
                    phase: .loaded
                )
            }

            // Enforced here rather than trusted from the caller: an `.initial` failure always
            // blanks the screen, a `.refresh` failure always preserves what was already showing
            //, regardless of what `previousLaunches` was actually passed as.
            let launchesOnError = errorPresentation == .initial ? [] : previousLaunches
            return with(
                launches: launchesOnError,
                pagination: pagination.clearingLoadMoreError(),
                phase: .error(message: errorMessage)
            )
        }

        let launches = kind == .loadMore ? previousLaunches.merging(page.items) : page.items
        return with(
            launches: launches,
            pagination: pagination.applying(page: page),
            phase: .loaded
        )
    }
}

// MARK: - LaunchListTrigger

enum LaunchListTrigger: Sendable {
    case onAppear
    case refresh
    case retry
    case modeChanged(LaunchListMode)
    case searchTextChanged(String)
    case launchAppeared(String)
    case retryLoadMore
}

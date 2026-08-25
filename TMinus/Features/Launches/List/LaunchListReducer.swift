//
//  LaunchListReducer.swift
//  TMinus
//
//  Created by Sadegh on 07/05/2026.
//

import Foundation

// MARK: - LaunchListAction

enum LaunchListAction: Sendable {
    case appear
    case refresh
    case retry
    case modeChanged(LaunchListMode)
    case searchTextChanged(String)
    case search(String)
    case loadMore
    case retryLoadMore
    case loadResponse(
        mode: LaunchListMode,
        searchText: String,
        previousLaunches: [Launch],
        page: PagedResult<Launch>,
        kind: ListLoadKind,
        errorPresentation: LoadPresentationKind,
        errorMessage: String?,
        generation: Int
    )
    /// Sent when the ViewModel cancels in-flight work (view disappearing) rather than a load ever
    /// resolving, without this, a load cancelled mid-flight leaves `phase` stuck at whatever
    /// `.loading` case started it forever, since no `loadResponse` ever arrives to move it on and
    /// every reducer guard above only accepts `.appear`/`.retry`/`.refresh`/`.loadMore` from a
    /// settled phase. See `LaunchListViewModel.cancelInFlightWork`.
    case cancelled
}

// MARK: - LaunchListEffect

enum LaunchListEffect: Sendable {
    case load(
        mode: LaunchListMode,
        searchText: String,
        page: Int,
        previousLaunches: [Launch],
        fetchPolicy: FetchPolicy,
        kind: ListLoadKind,
        errorPresentation: LoadPresentationKind,
        generation: Int
    )
}

// MARK: - LaunchListReducer

enum LaunchListReducer {
    static func reduce(state: LaunchListState,
                       action: LaunchListAction) -> (state: LaunchListState, effect: LaunchListEffect?)
    {
        switch action {
        case .appear:
            // Defense in depth, mirroring `LaunchDetailReducer.appear`, today the ViewModel's
            // `hasAppeared` flag is the only thing preventing a second `.appear` from wiping a
            // fully-loaded list back to `.loading(.initial)`; guarding on phase here makes that
            // idempotency a property of the reducer itself, not just of one call site.
            guard case .idle = state.phase else {
                return (state, nil)
            }
            let (nextState, generation) = state.startingInitialLoad()
            return (
                nextState,
                loadEffect(
                    mode: state.mode,
                    searchText: state.searchText,
                    page: 1,
                    previousLaunches: [],
                    fetchPolicy: .useCache,
                    kind: .fresh,
                    errorPresentation: .initial,
                    generation: generation
                )
            )

        case .retry:
            // Meaningful from the full-screen error state OR a genuinely-empty loaded state,
            // `ListScreenScaffold` surfaces the same retry button on both `.error` and `.empty`
            // (see its doc comment), and `.empty` covers `.loaded` with no items just as much as
            // `.error`. Without `.loaded` here, a zero-result search or a genuinely-empty list
            // left the retry button wired to a silent no-op. A `.refresh`-caused error (banner,
            // content still showing) has its own retry path via `.refresh`/pull-to-refresh instead.
            guard state.launches.isEmpty else {
                return (state, nil)
            }
            switch state.phase {
            case .error, .loaded:
                break
            case .idle, .loading:
                return (state, nil)
            }
            let (nextState, generation) = state.startingInitialLoad()
            return (
                nextState,
                loadEffect(
                    mode: state.mode,
                    searchText: state.searchText,
                    page: 1,
                    previousLaunches: [],
                    fetchPolicy: .useCache,
                    kind: .fresh,
                    errorPresentation: .initial,
                    generation: generation
                )
            )

        case .refresh:
            // Only meaningful once there's content to refresh, without this, a `.refresh`
            // firing while `launches` is empty (e.g. from a stray call before any successful
            // load) would move the phase to `.loading(.refresh)` while items stay empty, which
            // `ListContentPhase.derive` renders as `.empty` rather than a loading spinner: a
            // network request silently in flight with no visible indication of it.
            //
            // Also excludes an already-in-flight `.loading(.refresh)`, without this, a second
            // pull-to-refresh fired before the first completes passes the emptiness check and
            // starts an overlapping load. The generation guard in `applyingLoadResponse` and the
            // task coordinator's cancellation absorb that today, but excluding it here makes the
            // reducer itself provably idempotent rather than relying on that as a safety net.
            guard state.launches.isEmpty == false, state.phase != .loading(.refresh) else {
                return (state, nil)
            }
            let (nextState, generation) = state.startingRefresh()
            return (
                nextState,
                loadEffect(
                    mode: state.mode,
                    searchText: state.searchText,
                    page: 1,
                    previousLaunches: state.launches,
                    fetchPolicy: .networkOnly,
                    kind: .fresh,
                    errorPresentation: .refresh,
                    generation: generation
                )
            )

        case let .modeChanged(newMode):
            guard newMode != state.mode else {
                return (state, nil)
            }
            let (nextState, generation) = state.startingModeChange(newMode)
            return (
                nextState,
                loadEffect(
                    mode: newMode,
                    searchText: state.searchText,
                    page: 1,
                    previousLaunches: [],
                    fetchPolicy: .useCache,
                    kind: .fresh,
                    errorPresentation: .initial,
                    generation: generation
                )
            )

        case let .searchTextChanged(text):
            return (state.updatingSearchText(text), nil)

        case let .search(text):
            let (nextState, generation) = state.startingSearch(text)
            return (
                nextState,
                loadEffect(
                    mode: state.mode,
                    searchText: text,
                    page: 1,
                    previousLaunches: [],
                    fetchPolicy: .useCache,
                    kind: .fresh,
                    errorPresentation: .initial,
                    generation: generation
                )
            )

        case .retryLoadMore:
            guard case .loaded = state.phase,
                  let nextPage = state.pagination.retryLoadMorePage
            else {
                return (state, nil)
            }
            let (nextState, generation) = state.startingLoadMore()
            return (
                nextState,
                loadEffect(
                    mode: state.mode,
                    searchText: state.searchText,
                    page: nextPage,
                    previousLaunches: state.launches,
                    fetchPolicy: .networkOnly,
                    kind: .loadMore,
                    errorPresentation: .refresh,
                    generation: generation
                )
            )

        case .loadMore:
            guard case .loaded = state.phase,
                  state.pagination.loadMoreError == nil,
                  let nextPage = state.pagination.nextPage,
                  state.launches.isEmpty == false
            else {
                return (state, nil)
            }
            let (nextState, generation) = state.startingLoadMore()
            return (
                nextState,
                loadEffect(
                    mode: state.mode,
                    searchText: state.searchText,
                    page: nextPage,
                    previousLaunches: state.launches,
                    fetchPolicy: .networkOnly,
                    kind: .loadMore,
                    errorPresentation: .refresh,
                    generation: generation
                )
            )

        case let .loadResponse(mode, searchText, previousLaunches, page, kind, errorPresentation, errorMessage, generation):
            return (
                state.applyingLoadResponse(
                    mode: mode,
                    searchText: searchText,
                    previousLaunches: previousLaunches,
                    page: page,
                    kind: kind,
                    errorPresentation: errorPresentation,
                    errorMessage: errorMessage,
                    generation: generation
                ),
                nil
            )

        case .cancelled:
            switch state.phase {
            case .loading(.initial), .loading(.refresh):
                // Also advances the `.fresh` generation, `cancelInFlightWork()` guarantees
                // `loadTasks.cancelAll()` ran first, but that only stops *this* coordinator from
                // awaiting the task; `URLSessionNetworkClient`'s `InFlightRequestStore` can still
                // keep a coalesced `.useCache` fetch running for another joiner (see its doc
                // comment), and the task body only skips `send(.loadResponse(...))` if the fetch
                // itself throws `CancellationError`, it never checks `Task.isCancelled` first.
                // Without bumping the generation here, that late response would still pass
                // `applyingLoadResponse`'s generation guard and silently resurrect state after
                // this reducer already moved on to `.idle`/`.loaded`, and since `.appear` only
                // fires from `.idle`, a response landing after this and flipping phase to
                // `.loaded` would permanently swallow the next `.appear`.
                let (nextGenerations, _) = state.loadGenerations.advancing(for: .fresh)
                // Covers `.appear`, `.retry`, `.modeChanged`, and `.search` alike, all of them
                // clear `launches` before starting, so `.idle` is always a safe, empty resting
                // state to fall back to regardless of which one was cancelled. A cancelled
                // `.refresh` falls back to `.loaded` instead, since content from before it started
                // is still valid and still on screen.
                let phase: ListPhase = state.phase == .loading(.initial) ? .idle : .loaded
                return (state.with(phase: phase, loadGenerations: nextGenerations), nil)
            case .loading(.loadMore):
                let (nextGenerations, _) = state.loadGenerations.advancing(for: .loadMore)
                return (state.with(phase: .loaded, loadGenerations: nextGenerations), nil)
            case .idle, .loaded, .error:
                return (state, nil)
            }
        }
    }

    private static func loadEffect(mode: LaunchListMode,
                                   searchText: String,
                                   page: Int,
                                   previousLaunches: [Launch],
                                   fetchPolicy: FetchPolicy,
                                   kind: ListLoadKind,
                                   errorPresentation: LoadPresentationKind,
                                   generation: Int) -> LaunchListEffect
    {
        .load(
            mode: mode,
            searchText: searchText,
            page: page,
            previousLaunches: previousLaunches,
            fetchPolicy: fetchPolicy,
            kind: kind,
            errorPresentation: errorPresentation,
            generation: generation
        )
    }
}

// MARK: ReducerProtocol

extension LaunchListReducer: ReducerProtocol {}

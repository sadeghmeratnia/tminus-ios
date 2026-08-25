//
//  LaunchListViewModel.swift
//  TMinus
//
//  Created by Sadegh on 06/05/2026.
//

import Combine
import Foundation

// MARK: - LaunchListViewModel

@MainActor
final class LaunchListViewModel: ReducingStoreProtocol {
    typealias Mode = LaunchListMode
    typealias State = LaunchListState
    typealias Trigger = LaunchListTrigger
    typealias Action = LaunchListAction
    typealias Effect = LaunchListEffect
    typealias Reducer = LaunchListReducer

    @Published private(set) var state: State = .initial

    private let fetchUpcomingLaunchesUseCase: FetchUpcomingLaunchesUseCase
    private let fetchPreviousLaunchesUseCase: FetchPreviousLaunchesUseCase
    private var hasAppeared = false
    private let loadTasks = ListLoadTaskCoordinator()
    private var searchDebounceTask: Task<Void, Never>?
    /// The most recently started `.fresh` load's `Task`, captured purely so `refresh()` can
    /// await it, see `ViewModelProtocol.refresh()`.
    private var freshLoadTask: Task<Void, Never>?
    /// The text a `.fresh` load most recently *succeeded* for, see `NewsListViewModel`'s
    /// equivalent property for the full rationale (distinguishing "already loaded this" from
    /// "user is currently typing this", and why it's a ViewModel-only dedup concern).
    private var lastLoadedSearchText: String?

    init(fetchUpcomingLaunchesUseCase: FetchUpcomingLaunchesUseCase,
         fetchPreviousLaunchesUseCase: FetchPreviousLaunchesUseCase)
    {
        self.fetchUpcomingLaunchesUseCase = fetchUpcomingLaunchesUseCase
        self.fetchPreviousLaunchesUseCase = fetchPreviousLaunchesUseCase
    }

    deinit {
        searchDebounceTask?.cancel()
    }

    func onTrigger(_ trigger: Trigger) {
        switch trigger {
        case .onAppear:
            guard hasAppeared == false else { return }
            hasAppeared = true
            send(.appear)

        case .refresh:
            // A pending debounced search must not fire after this: it would re-dispatch
            // `.search` against a mode/search state this refresh has already moved past,
            // flashing the list back to empty and restarting the load `.refresh` just kicked
            // off. See `debounceSearch` for the matching `lastLoadedSearchText` dedup this
            // cancellation complements.
            searchDebounceTask?.cancel()
            send(.refresh)

        case .retry:
            searchDebounceTask?.cancel()
            send(.retry)

        case let .modeChanged(newMode):
            searchDebounceTask?.cancel()
            send(.modeChanged(newMode))

        case let .searchTextChanged(text):
            send(.searchTextChanged(text))
            debounceSearch(text)

        case let .launchAppeared(id):
            guard state.launches.last?.id == id else { return }
            send(.loadMore)

        case .retryLoadMore:
            send(.retryLoadMore)
        }
    }

    func cancelInFlightWork() {
        searchDebounceTask?.cancel()
        loadTasks.cancelAll()
        // A cancelled `.loading(.initial)` load means `hasAppeared` can no longer be trusted: the
        // `.task { onTrigger(.onAppear) }` that will fire the next time this screen appears is
        // this screen's only way back out of `.idle`, and that trigger is a silent no-op while
        // `hasAppeared` stays true. See `LaunchListReducer.cancelled` for the matching phase reset.
        if case .loading(.initial) = state.phase {
            hasAppeared = false
        }
        send(.cancelled)
    }

    func refresh() async {
        onTrigger(.refresh)
        await freshLoadTask?.value
    }

    private func send(_ action: LaunchListAction) {
        let (newState, effect) = Reducer.reduce(state: state, action: action)
        state = newState
        if let effect {
            run(effect)
        }
    }

    private func run(_ effect: LaunchListEffect) {
        switch effect {
        case let .load(mode, searchText, page, previousLaunches, fetchPolicy, kind, errorPresentation, generation):
            let task = loadTasks.start(kind, owner: self) { `self` in
                let pagedResult: PagedResult<Launch>
                let errorMessage: String?
                do {
                    let query = LaunchListQuery(
                        page: page,
                        limit: ListPageSize.default,
                        searchText: searchText,
                        fetchPolicy: fetchPolicy
                    )
                    pagedResult = try await {
                        switch mode {
                        case .upcoming:
                            return try await self.fetchUpcomingLaunchesUseCase.execute(query: query)
                        case .previous:
                            return try await self.fetchPreviousLaunchesUseCase.execute(query: query)
                        }
                    }()
                    errorMessage = nil
                } catch is CancellationError {
                    return
                } catch let presentable as UserMessagePresentable {
                    pagedResult = PagedResult(items: [], currentPage: page)
                    errorMessage = presentable.userMessage
                } catch {
                    pagedResult = PagedResult(items: [], currentPage: page)
                    errorMessage = L10n.Error.Network.unknown
                }

                self.send(
                    .loadResponse(
                        mode: mode,
                        searchText: searchText,
                        previousLaunches: previousLaunches,
                        page: pagedResult,
                        kind: kind,
                        errorPresentation: errorPresentation,
                        errorMessage: errorMessage,
                        generation: generation
                    )
                )

                // Record the search only if this response was accepted. A newer query may have
                // replaced it while the request was running.
                if kind == .fresh,
                   errorMessage == nil,
                   Task.isCancelled == false,
                   self.state.searchText == searchText,
                   self.state.loadGenerations.matches(generation, for: .fresh)
                {
                    self.lastLoadedSearchText = searchText
                }
            }
            if kind == .fresh {
                freshLoadTask = task
            }
        }
    }
}

// MARK: - Search debounce

extension LaunchListViewModel {
    private func debounceSearch(_ text: String) {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task { [weak self] in
            try? await Task.sleep(for: Constants.searchDebounceDelay)
            guard Task.isCancelled == false, let self, text != self.lastLoadedSearchText else { return }
            self.send(.search(text))
        }
    }

    private enum Constants {
        static let searchDebounceDelay = Duration.milliseconds(400)
    }
}

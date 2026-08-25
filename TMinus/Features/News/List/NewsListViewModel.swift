//
//  NewsListViewModel.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import Combine
import Foundation

// MARK: - NewsListViewModel

@MainActor
final class NewsListViewModel: ReducingStoreProtocol {
    typealias State = NewsListState
    typealias Trigger = NewsListTrigger
    typealias Action = NewsListAction
    typealias Effect = NewsListEffect
    typealias Reducer = NewsListReducer

    @Published private(set) var state: State = .initial

    private let fetchNewsArticlesUseCase: FetchNewsArticlesUseCase
    private var hasAppeared = false
    private let loadTasks = ListLoadTaskCoordinator()
    private var searchDebounceTask: Task<Void, Never>?
    /// The most recently started `.fresh` load's `Task`, captured purely so `refresh()` can
    /// await it, see `ViewModelProtocol.refresh()`.
    private var freshLoadTask: Task<Void, Never>?
    /// The text a `.fresh` load most recently *succeeded* for, distinct from `state.searchText`,
    /// which already reflects live typing before the debounce settles, so the reducer can't tell
    /// "already loaded this" from "user is currently typing this". Only set on success so a search
    /// that failed can always be retried by retyping the same text; this mirrors `hasAppeared`, a
    /// ViewModel-only dedup concern rather than reducer/state business logic.
    private var lastLoadedSearchText: String?

    init(fetchNewsArticlesUseCase: FetchNewsArticlesUseCase) {
        self.fetchNewsArticlesUseCase = fetchNewsArticlesUseCase
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
            // See `LaunchListViewModel.onTrigger`, a pending debounced search must not fire
            // after this, or it re-dispatches `.search` against state this refresh has already
            // moved past, flashing the list back to empty.
            searchDebounceTask?.cancel()
            send(.refresh)

        case .retry:
            searchDebounceTask?.cancel()
            send(.retry)

        case let .searchTextChanged(text):
            send(.searchTextChanged(text))
            debounceSearch(text)

        case let .articleAppeared(id):
            guard state.articles.last?.id == id else { return }
            send(.loadMore)

        case .retryLoadMore:
            send(.retryLoadMore)
        }
    }

    func cancelInFlightWork() {
        searchDebounceTask?.cancel()
        loadTasks.cancelAll()
        // See `LaunchListViewModel.cancelInFlightWork`, a cancelled `.loading(.initial)` load
        // means `hasAppeared` can no longer be trusted to gate the next `.onAppear`.
        if case .loading(.initial) = state.phase {
            hasAppeared = false
        }
        send(.cancelled)
    }

    func refresh() async {
        onTrigger(.refresh)
        await freshLoadTask?.value
    }

    private func send(_ action: NewsListAction) {
        let (newState, effect) = Reducer.reduce(state: state, action: action)
        state = newState
        if let effect {
            run(effect)
        }
    }

    private func run(_ effect: NewsListEffect) {
        switch effect {
        case let .load(searchText, page, previousArticles, fetchPolicy, kind, errorPresentation, generation):
            let task = loadTasks.start(kind, owner: self) { `self` in
                let pagedResult: PagedResult<NewsArticle>
                let errorMessage: String?
                do {
                    let query = NewsListQuery(
                        page: page,
                        limit: ListPageSize.default,
                        searchText: searchText,
                        fetchPolicy: fetchPolicy
                    )
                    pagedResult = try await self.fetchNewsArticlesUseCase.execute(query: query)
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
                        searchText: searchText,
                        previousArticles: previousArticles,
                        page: pagedResult,
                        kind: kind,
                        errorPresentation: errorPresentation,
                        errorMessage: errorMessage,
                        generation: generation
                    )
                )

                // Stamped *after* `send`, and gated on `self.state` actually reflecting this
                // response, see `LaunchListViewModel`'s equivalent for the full rationale.
                // `Task.isCancelled` alone isn't enough: `applyingLoadResponse`'s own guard can
                // reject a response that finished perfectly normally (the user kept typing while
                // it was in flight), and stamping in that case would wrongly mark `searchText` as
                // "already loaded," permanently blocking the debounce from ever retrying it.
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

extension NewsListViewModel {
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

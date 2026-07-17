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
    private var loadTasks: [ListLoadKind: Task<Void, Never>] = [:]
    private var searchDebounceTask: Task<Void, Never>?

    init(fetchNewsArticlesUseCase: FetchNewsArticlesUseCase) {
        self.fetchNewsArticlesUseCase = fetchNewsArticlesUseCase
    }

    deinit {
        loadTasks.values.forEach { $0.cancel() }
        searchDebounceTask?.cancel()
    }

    func onTrigger(_ trigger: Trigger) {
        switch trigger {
        case .onAppear:
            guard hasAppeared == false else { return }
            hasAppeared = true
            send(.appear)

        case .refresh:
            send(.refresh)

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

    func send(_ action: NewsListAction) {
        let (newState, effect) = Reducer.reduce(state: state, action: action)
        state = newState
        if let effect {
            run(effect)
        }
    }

    func run(_ effect: NewsListEffect) {
        switch effect {
        case let .load(searchText, page, previousArticles, fetchPolicy, kind, generation):
            kind.cancels.forEach { loadTasks[$0]?.cancel() }
            loadTasks[kind] = Task { [weak self] in
                guard let self else { return }

                let pagedResult: PagedResult<NewsArticle>
                let errorMessage: String?
                do {
                    let query = NewsListQuery(page: page, limit: 20, searchText: searchText, fetchPolicy: fetchPolicy)
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
                        errorMessage: errorMessage,
                        generation: generation
                    )
                )
            }
        }
    }
}

// MARK: - Search debounce

extension NewsListViewModel {
    private func debounceSearch(_ text: String) {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Constants.searchDebounceNanoseconds)
            guard Task.isCancelled == false else { return }
            self?.send(.search(text))
        }
    }

    private enum Constants {
        static let searchDebounceNanoseconds: UInt64 = 400_000_000
    }
}

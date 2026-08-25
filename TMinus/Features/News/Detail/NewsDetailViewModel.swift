//
//  NewsDetailViewModel.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import Combine
import Foundation

@MainActor
final class NewsDetailViewModel: ReducingStoreProtocol {
    typealias State = NewsDetailState
    typealias Trigger = NewsDetailTrigger
    typealias Action = NewsDetailAction
    typealias Effect = NewsDetailEffect
    typealias Reducer = NewsDetailReducer

    @Published private(set) var state: State

    private let fetchNewsArticleDetailUseCase: FetchNewsArticleDetailUseCase
    private var hasAppeared = false
    private let loadTasks = DetailLoadTaskCoordinator()
    /// The most recently started main-load `Task`, captured purely so `refresh()` can await it,
    /// see `ViewModelProtocol.refresh()`.
    private var mainLoadTask: Task<Void, Never>?

    init(articleID: String, fetchNewsArticleDetailUseCase: FetchNewsArticleDetailUseCase) {
        state = .initial(articleID: articleID)
        self.fetchNewsArticleDetailUseCase = fetchNewsArticleDetailUseCase
    }

    func onTrigger(_ trigger: Trigger) {
        switch trigger {
        case .onAppear:
            guard hasAppeared == false else { return }
            hasAppeared = true
            send(.appear)

        case .retry:
            // Mirrors `LaunchDetailViewModel`'s equivalent guard, see there for why this
            // ViewModel checks phase itself rather than trusting the view to only ever send
            // `.retry` from the error state.
            guard case .error = state.phase else { return }
            send(.retry)

        case .refresh:
            // Mirrors `LaunchDetailViewModel`'s equivalent guard.
            guard case .loaded = state.phase else { return }
            send(.refresh)
        }
    }

    func cancelInFlightWork() {
        loadTasks.cancelAll()
        // See `LaunchDetailViewModel.cancelInFlightWork`, a cancelled `.loading` load means
        // `hasAppeared` can no longer be trusted to gate the next `.onAppear`.
        if case .loading = state.phase {
            hasAppeared = false
        }
        send(.cancelled)
    }

    func refresh() async {
        onTrigger(.refresh)
        await mainLoadTask?.value
    }

    private func send(_ action: NewsDetailAction) {
        let (newState, effect) = Reducer.reduce(state: state, action: action)
        state = newState
        if let effect {
            run(effect)
        }
    }

    private func run(_ effect: NewsDetailEffect) {
        switch effect {
        case let .load(id, fetchPolicy, kind, generation):
            mainLoadTask = loadTasks.start(.main, owner: self) { `self` in
                let result: NewsDetailLoadOutcome
                do {
                    result = try .success(await self.fetchNewsArticleDetailUseCase.execute(id: id, fetchPolicy: fetchPolicy))
                } catch is CancellationError {
                    return
                } catch let presentable as UserMessagePresentable {
                    result = .failure(presentable.userMessage)
                } catch {
                    result = .failure(L10n.Error.Network.unknown)
                }

                self.send(.loadResponse(result, kind: kind, generation: generation))
            }
        }
    }
}

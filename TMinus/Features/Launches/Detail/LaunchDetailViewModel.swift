//
//  LaunchDetailViewModel.swift
//  TMinus
//
//  Created by Sadegh on 28/05/2026.
//

import Combine
import Foundation

@MainActor
final class LaunchDetailViewModel: ReducingStoreProtocol {
    typealias State = LaunchDetailState
    typealias Trigger = LaunchDetailTrigger
    typealias Action = LaunchDetailAction
    typealias Effect = LaunchDetailEffect
    typealias Reducer = LaunchDetailReducer

    @Published private(set) var state: State

    private let fetchLaunchDetailUseCase: FetchLaunchDetailUseCase
    private let fetchRelatedNewsUseCase: FetchRelatedNewsUseCase
    private var hasAppeared = false
    private var loadTask: Task<Void, Never>?
    private var relatedNewsTask: Task<Void, Never>?

    init(launchID: String,
         fetchLaunchDetailUseCase: FetchLaunchDetailUseCase,
         fetchRelatedNewsUseCase: FetchRelatedNewsUseCase) {
        self.state = .initial(launchID: launchID)
        self.fetchLaunchDetailUseCase = fetchLaunchDetailUseCase
        self.fetchRelatedNewsUseCase = fetchRelatedNewsUseCase
    }

    deinit {
        loadTask?.cancel()
        relatedNewsTask?.cancel()
    }

    func onTrigger(_ trigger: Trigger) {
        switch trigger {
        case .onAppear:
            guard hasAppeared == false else { return }
            hasAppeared = true
            send(.appear)
            loadRelatedNews()

        case .retry:
            send(.retry)
        }
    }

    func send(_ action: LaunchDetailAction) {
        let (newState, effect) = Reducer.reduce(state: state, action: action)
        state = newState
        if let effect {
            run(effect)
        }
    }

    func run(_ effect: LaunchDetailEffect) {
        switch effect {
        case let .load(id):
            loadTask?.cancel()
            loadTask = Task { [weak self] in
                guard let self else { return }

                let launch: Launch?
                let errorMessage: String?
                do {
                    launch = try await self.fetchLaunchDetailUseCase.execute(id: id)
                    errorMessage = nil
                } catch is CancellationError {
                    return
                } catch let presentable as UserMessagePresentable {
                    launch = nil
                    errorMessage = presentable.userMessage
                } catch {
                    launch = nil
                    errorMessage = L10n.Error.Network.unknown
                }

                self.send(.loadResponse(launch: launch, errorMessage: errorMessage))
            }
        }
    }
}

// MARK: - Related news

extension LaunchDetailViewModel {
    /// Best-effort: never gates the main launch load and swallows all failures,
    /// since the section simply doesn't appear when there's nothing to show.
    private func loadRelatedNews() {
        relatedNewsTask?.cancel()
        relatedNewsTask = Task { [weak self] in
            guard let self else { return }

            let articles: [NewsArticle]
            do {
                articles = try await self.fetchRelatedNewsUseCase.execute(launchID: self.state.launchID)
            } catch {
                articles = []
            }

            guard Task.isCancelled == false else { return }
            self.send(.relatedNewsResponse(articles))
        }
    }
}

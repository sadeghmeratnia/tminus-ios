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
    private var loadTask: Task<Void, Never>?

    init(articleID: String, fetchNewsArticleDetailUseCase: FetchNewsArticleDetailUseCase) {
        self.state = .initial(articleID: articleID)
        self.fetchNewsArticleDetailUseCase = fetchNewsArticleDetailUseCase
    }

    deinit {
        loadTask?.cancel()
    }

    func onTrigger(_ trigger: Trigger) {
        switch trigger {
        case .onAppear:
            guard hasAppeared == false else { return }
            hasAppeared = true
            send(.appear)

        case .retry:
            send(.retry)
        }
    }

    func send(_ action: NewsDetailAction) {
        let (newState, effect) = Reducer.reduce(state: state, action: action)
        state = newState
        if let effect {
            run(effect)
        }
    }

    func run(_ effect: NewsDetailEffect) {
        switch effect {
        case let .load(id):
            loadTask?.cancel()
            loadTask = Task { [weak self] in
                guard let self else { return }

                let article: NewsArticle?
                let errorMessage: String?
                do {
                    article = try await self.fetchNewsArticleDetailUseCase.execute(id: id)
                    errorMessage = nil
                } catch is CancellationError {
                    return
                } catch let presentable as UserMessagePresentable {
                    article = nil
                    errorMessage = presentable.userMessage
                } catch {
                    article = nil
                    errorMessage = L10n.Error.Network.unknown
                }

                self.send(.loadResponse(article: article, errorMessage: errorMessage))
            }
        }
    }
}

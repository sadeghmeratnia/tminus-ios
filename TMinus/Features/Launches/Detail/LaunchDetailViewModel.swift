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
    private var hasAppeared = false
    private var loadTask: Task<Void, Never>?

    init(launchID: String, fetchLaunchDetailUseCase: FetchLaunchDetailUseCase) {
        self.state = .initial(launchID: launchID)
        self.fetchLaunchDetailUseCase = fetchLaunchDetailUseCase
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
                } catch let launchError as LaunchError {
                    launch = nil
                    errorMessage = launchError.userMessage
                } catch {
                    launch = nil
                    errorMessage = LaunchError.unknown(underlying: error).userMessage
                }

                self.send(.loadResponse(launch: launch, errorMessage: errorMessage))
            }
        }
    }
}

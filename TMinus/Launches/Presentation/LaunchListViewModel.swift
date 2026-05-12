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

    @Published private(set) var state: State = .idle(mode: .upcoming)

    private let fetchUpcomingLaunchesUseCase: FetchUpcomingLaunchesUseCase
    private let fetchPreviousLaunchesUseCase: FetchPreviousLaunchesUseCase
    private var hasAppeared = false
    private var loadTask: Task<Void, Never>?

    init(fetchUpcomingLaunchesUseCase: FetchUpcomingLaunchesUseCase,
         fetchPreviousLaunchesUseCase: FetchPreviousLaunchesUseCase) {
        self.fetchUpcomingLaunchesUseCase = fetchUpcomingLaunchesUseCase
        self.fetchPreviousLaunchesUseCase = fetchPreviousLaunchesUseCase
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

        case .refresh:
            send(.refresh)

        case let .modeChanged(newMode):
            send(.modeChanged(newMode))
        }
    }

    func send(_ action: LaunchListAction) {
        let (newState, effect) = Reducer.reduce(state: state, action: action)
        state = newState
        if let effect {
            run(effect)
        }
    }

    func run(_ effect: LaunchListEffect) {
        switch effect {
        case let .load(mode, previousLaunches):
            loadTask?.cancel()
            loadTask = Task { [weak self] in
                guard let self else { return }

                let launches: [Launch]
                let errorMessage: String?
                do {
                    let query = LaunchListQuery(page: 1, limit: 20)
                    launches = try await {
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
                } catch let networkError as NetworkError {
                    launches = []
                    errorMessage = networkError.userMessage
                } catch {
                    launches = []
                    errorMessage = L10n.Error.Network.unknown
                }

                await MainActor.run {
                    self.send(
                        .loadResponse(
                            mode: mode,
                            previousLaunches: previousLaunches,
                            launches: launches,
                            errorMessage: errorMessage))
                }
            }
        }
    }
}

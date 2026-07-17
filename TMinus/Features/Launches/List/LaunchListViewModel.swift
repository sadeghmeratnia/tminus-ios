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
    private var loadTasks: [ListLoadKind: Task<Void, Never>] = [:]

    init(fetchUpcomingLaunchesUseCase: FetchUpcomingLaunchesUseCase,
         fetchPreviousLaunchesUseCase: FetchPreviousLaunchesUseCase) {
        self.fetchUpcomingLaunchesUseCase = fetchUpcomingLaunchesUseCase
        self.fetchPreviousLaunchesUseCase = fetchPreviousLaunchesUseCase
    }

    deinit {
        loadTasks.values.forEach { $0.cancel() }
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

        case let .launchAppeared(id):
            guard state.launches.last?.id == id else { return }
            send(.loadMore)

        case .retryLoadMore:
            send(.retryLoadMore)
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
        case let .load(mode, page, previousLaunches, fetchPolicy, kind, generation):
            kind.cancels.forEach { loadTasks[$0]?.cancel() }
            loadTasks[kind] = Task { [weak self] in
                guard let self else { return }

                let pagedResult: PagedResult<Launch>
                let errorMessage: String?
                do {
                    let query = LaunchListQuery(page: page, limit: 20, fetchPolicy: fetchPolicy)
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
                        previousLaunches: previousLaunches,
                        page: pagedResult,
                        kind: kind,
                        errorMessage: errorMessage,
                        generation: generation))
            }
        }
    }
}

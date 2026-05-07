//
//  LaunchListViewModel.swift
//  TMinus
//
//  Created by Sadegh on 06/05/2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class LaunchListViewModel {
    enum Mode: String, CaseIterable, Identifiable {
        case upcoming
        case previous

        var id: String {
            rawValue
        }

        var title: String {
            switch self {
            case .upcoming:
                return L10n.Launches.Mode.upcoming
            case .previous:
                return L10n.Launches.Mode.previous
            }
        }
    }

    var mode: Mode = .upcoming
    var launches: [Launch] = []
    var isLoading = false
    var errorMessage: String?

    private let fetchUpcomingLaunchesUseCase: FetchUpcomingLaunchesUseCase
    private let fetchPreviousLaunchesUseCase: FetchPreviousLaunchesUseCase

    init(fetchUpcomingLaunchesUseCase: FetchUpcomingLaunchesUseCase,
         fetchPreviousLaunchesUseCase: FetchPreviousLaunchesUseCase) {
        self.fetchUpcomingLaunchesUseCase = fetchUpcomingLaunchesUseCase
        self.fetchPreviousLaunchesUseCase = fetchPreviousLaunchesUseCase
    }

    func load() async {
        guard isLoading == false else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let query = LaunchListQuery(page: 1, limit: 20)
            launches = switch mode {
            case .upcoming:
                try await fetchUpcomingLaunchesUseCase.execute(query: query)
            case .previous:
                try await fetchPreviousLaunchesUseCase.execute(query: query)
            }
        } catch let networkError as NetworkError {
            errorMessage = networkError.userMessage
        } catch {
            errorMessage = L10n.Error.Network.unknown
        }
    }
}

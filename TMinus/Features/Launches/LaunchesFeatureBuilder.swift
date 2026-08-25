//
//  LaunchesFeatureBuilder.swift
//  TMinus
//
//  Created by Sadegh on 22/05/2026.
//

import Foundation
import SwiftData

// MARK: - LaunchesFeatureBuilder

/// `@MainActor`-isolated so `repository`'s lazy initialization is compiler-enforced race-safe,
/// mirrors `NewsFeatureBuilder`'s identical rationale. Nothing outside this type currently calls
/// `makeRepository()` a second time the way `AppCoordinator` does for `NewsFeatureBuilder`, but
/// keeping both builders' repository-sharing story identical means a future consumer that needs
/// to reuse the Launches repository elsewhere gets a real shared instance instead of silently
/// standing up a second SwiftData access path.
@MainActor
final class LaunchesFeatureBuilder {
    struct Dependencies {
        let networkClient: NetworkClientProtocol
        let modelContainer: ModelContainer
        /// A dependency of Launches on News's data, taken deliberately rather than hidden behind
        /// a singleton, `fetchRelatedNewsUseCase` below is the only consumer. Typed as
        /// `RelatedNewsProviding` (declared in `Core`, owned by neither feature) rather than
        /// `NewsRepositoryProtocol`, so this is a dependency on the one query Launches actually
        /// needs, not on News's entire repository surface. `AppCoordinator` passes
        /// `NewsFeatureBuilder.makeRepository()`'s result straight through here, any
        /// `NewsRepositoryProtocol` value already satisfies `RelatedNewsProviding`, since the
        /// former refines the latter, so no adapter or cast is needed at the call site.
        let relatedNewsProvider: RelatedNewsProviding
    }

    private let dependencies: Dependencies

    private lazy var repository: LaunchRepositoryProtocol = {
        let remote = NetworkLaunchRemoteDataSource(networkClient: dependencies.networkClient)
        let local = SwiftDataLaunchLocalDataSource(container: dependencies.modelContainer)
        return LaunchRepository(remoteDataSource: remote, localDataSource: local)
    }()

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func makeCoordinator() -> LaunchesCoordinator {
        let repository = makeRepository()
        let launchListBuilder = LaunchListBuilder(
            viewModel: LaunchListViewModel(
                fetchUpcomingLaunchesUseCase: FetchUpcomingLaunchesUseCase(repository: repository),
                fetchPreviousLaunchesUseCase: FetchPreviousLaunchesUseCase(repository: repository)
            )
        )
        let launchDetailBuilder = LaunchDetailBuilder(
            fetchLaunchDetailUseCase: FetchLaunchDetailUseCase(repository: repository),
            fetchRelatedNewsUseCase: FetchRelatedNewsUseCase(relatedNewsProvider: dependencies.relatedNewsProvider)
        )
        return LaunchesCoordinator(
            launchListBuilder: launchListBuilder,
            launchDetailBuilder: launchDetailBuilder
        )
    }

    func makeRepository() -> LaunchRepositoryProtocol {
        repository
    }
}

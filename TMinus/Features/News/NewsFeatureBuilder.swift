//
//  NewsFeatureBuilder.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import Foundation
import SwiftData

// MARK: - NewsFeatureBuilder

/// `@MainActor`-isolated so `repository`'s lazy initialization, shared, mutable state read from
/// two independent call sites (`makeCoordinator()` and `makeRepository()`, called directly by
/// `AppCoordinator` for Launches' related-articles section), can never race. Every current call
/// site already runs on the main actor; this makes that a compiler-enforced guarantee rather than
/// a convention.
@MainActor
final class NewsFeatureBuilder {
    struct Dependencies {
        let networkClient: NetworkClientProtocol
        let modelContainer: ModelContainer
    }

    private let dependencies: Dependencies

    /// Shared across every consumer (the News tab and any other feature, e.g. Launches' related
    /// articles) so they all see the same repository instance rather than independent graphs.
    private lazy var repository: NewsRepositoryProtocol = {
        let remote = NetworkNewsRemoteDataSource(networkClient: dependencies.networkClient)
        let local = SwiftDataNewsLocalDataSource(container: dependencies.modelContainer)
        return NewsRepository(remoteDataSource: remote, localDataSource: local)
    }()

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func makeCoordinator() -> NewsCoordinator {
        let repository = makeRepository()
        let newsListBuilder = NewsListBuilder(
            viewModel: NewsListViewModel(fetchNewsArticlesUseCase: FetchNewsArticlesUseCase(repository: repository))
        )
        let newsDetailBuilder = NewsDetailBuilder(
            fetchNewsArticleDetailUseCase: FetchNewsArticleDetailUseCase(repository: repository)
        )
        return NewsCoordinator(
            newsListBuilder: newsListBuilder,
            newsDetailBuilder: newsDetailBuilder
        )
    }

    func makeRepository() -> NewsRepositoryProtocol {
        repository
    }
}

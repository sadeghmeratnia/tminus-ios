//
//  NewsFeatureBuilder.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import Foundation
import SwiftUI

// MARK: - NewsFeatureBuilder

final class NewsFeatureBuilder {
    struct Dependencies {
        let networkClient: NetworkClientProtocol
    }

    private let dependencies: Dependencies

    /// Shared across every consumer (the News tab and any other feature, e.g. Launches' related
    /// articles) so they all see the same repository instance rather than independent graphs.
    private lazy var repository: NewsRepositoryProtocol = {
        let remote = NetworkNewsRemoteDataSource(networkClient: dependencies.networkClient)
        return NewsRepository(remoteDataSource: remote)
    }()

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    @MainActor
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

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

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    @MainActor
    func makeCoordinator() -> NewsCoordinator {
        let repository = self.makeRepository()
        let newsListBuilder = NewsListBuilder(
            viewModel: NewsListViewModel(fetchNewsArticlesUseCase: FetchNewsArticlesUseCase(repository: repository)))
        let newsDetailBuilder = NewsDetailBuilder(
            fetchNewsArticleDetailUseCase: FetchNewsArticleDetailUseCase(repository: repository))
        return NewsCoordinator(
            newsListBuilder: newsListBuilder,
            newsDetailBuilder: newsDetailBuilder)
    }

    func makeRepository() -> NewsRepositoryProtocol {
        let remote = NetworkNewsRemoteDataSource(networkClient: dependencies.networkClient)
        return NewsRepository(remoteDataSource: remote)
    }
}

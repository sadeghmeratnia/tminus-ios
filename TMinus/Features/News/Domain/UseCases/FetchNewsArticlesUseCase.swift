//
//  FetchNewsArticlesUseCase.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import Foundation

struct FetchNewsArticlesUseCase {
    private let repository: NewsRepositoryProtocol

    init(repository: NewsRepositoryProtocol) {
        self.repository = repository
    }

    func execute(query: NewsListQuery) async throws -> PagedResult<NewsArticle> {
        try await repository.fetchArticles(query: query)
    }
}

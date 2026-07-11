//
//  FetchNewsArticleDetailUseCase.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import Foundation

struct FetchNewsArticleDetailUseCase {
    private let repository: NewsRepositoryProtocol

    init(repository: NewsRepositoryProtocol) {
        self.repository = repository
    }

    func execute(id: String) async throws -> NewsArticle {
        try await repository.fetchArticleDetail(id: id)
    }
}

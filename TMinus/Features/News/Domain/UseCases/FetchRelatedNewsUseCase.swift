//
//  FetchRelatedNewsUseCase.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import Foundation

/// Consumed by the Launches feature to surface articles related to a specific launch,
/// proving `NewsRepositoryProtocol` is shared infrastructure rather than duplicated per feature.
struct FetchRelatedNewsUseCase {
    private let repository: NewsRepositoryProtocol

    init(repository: NewsRepositoryProtocol) {
        self.repository = repository
    }

    func execute(launchID: String, limit: Int = 5) async throws -> [NewsArticle] {
        try await repository.fetchRelatedArticles(launchID: launchID, limit: limit)
    }
}

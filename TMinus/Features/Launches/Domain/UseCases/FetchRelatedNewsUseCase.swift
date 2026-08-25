//
//  FetchRelatedNewsUseCase.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import Foundation

/// A Launches use case, despite fetching News data, it exists to serve Launches' related-news
/// section, so it belongs with the feature that consumes it rather than the one that happens to
/// hold the data. Depends on `RelatedNewsProviding` (declared in `Core`), not
/// `NewsRepositoryProtocol` directly, so this feature's dependency on News is exactly the one
/// query it needs, not News's whole repository surface. See `LaunchesFeatureBuilder.Dependencies`
/// for how the concrete `NewsRepository` is wired in from the composition root.
struct FetchRelatedNewsUseCase {
    private let relatedNewsProvider: RelatedNewsProviding

    init(relatedNewsProvider: RelatedNewsProviding) {
        self.relatedNewsProvider = relatedNewsProvider
    }

    func execute(launchID: String, limit: Int = 5, fetchPolicy: FetchPolicy = .useCache) async throws -> [NewsArticle] {
        try await relatedNewsProvider.fetchRelatedArticles(launchID: launchID, limit: limit, fetchPolicy: fetchPolicy)
    }
}

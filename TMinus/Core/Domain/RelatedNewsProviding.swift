//
//  RelatedNewsProviding.swift
//  TMinus
//
//  Created by Sadegh on 16/08/2026.
//

import Foundation

// MARK: - RelatedNewsProviding

/// The small piece of the News repository that Launches needs for related articles.
/// It lives in Core so neither feature has to depend on the other.
protocol RelatedNewsProviding: Sendable {
    func fetchRelatedArticles(launchID: String, limit: Int, fetchPolicy: FetchPolicy) async throws -> [NewsArticle]
}

extension RelatedNewsProviding {
    /// Uses the cache by default for normal and best-effort loads.
    func fetchRelatedArticles(launchID: String, limit: Int) async throws -> [NewsArticle] {
        try await fetchRelatedArticles(launchID: launchID, limit: limit, fetchPolicy: .useCache)
    }
}

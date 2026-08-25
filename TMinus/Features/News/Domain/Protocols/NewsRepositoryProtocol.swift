//
//  NewsRepositoryProtocol.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import Foundation

// MARK: - NewsRepositoryProtocol

/// Refines `RelatedNewsProviding` (declared in `Core`, not owned by either feature) rather than
/// redeclaring `fetchRelatedArticles` itself, this file has no dependency on Launches, and
/// `fetchRelatedArticles`'s requirement, plus its `.useCache`-defaulting convenience overload,
/// both come from that shared protocol instead of being duplicated here.
protocol NewsRepositoryProtocol: RelatedNewsProviding {
    func fetchArticles(query: NewsListQuery) async throws -> PagedResult<NewsArticle>
    func fetchArticleDetail(id: String, fetchPolicy: FetchPolicy) async throws -> NewsArticle
}

// MARK: - NewsListQuery

struct NewsListQuery: Equatable, Sendable {
    let page: Int
    let limit: Int
    let searchText: String?
    let fetchPolicy: FetchPolicy

    init(page: Int = 1,
         limit: Int = ListPageSize.default,
         searchText: String? = nil,
         fetchPolicy: FetchPolicy = .useCache)
    {
        self.page = page
        self.limit = limit
        self.searchText = searchText?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.fetchPolicy = fetchPolicy
    }
}

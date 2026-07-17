//
//  NewsRepositoryProtocol.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import Foundation

// MARK: - NewsRepositoryProtocol

protocol NewsRepositoryProtocol: Sendable {
    func fetchArticles(query: NewsListQuery) async throws -> PagedResult<NewsArticle>
    func fetchArticleDetail(id: String) async throws -> NewsArticle
    func fetchRelatedArticles(launchID: String, limit: Int) async throws -> [NewsArticle]
}

// MARK: - NewsListQuery

struct NewsListQuery: Equatable, Sendable {
    let page: Int
    let limit: Int
    let searchText: String?
    let fetchPolicy: FetchPolicy

    init(page: Int = 1,
         limit: Int = 20,
         searchText: String? = nil,
         fetchPolicy: FetchPolicy = .useCache) {
        self.page = page
        self.limit = limit
        self.searchText = searchText?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.fetchPolicy = fetchPolicy
    }
}

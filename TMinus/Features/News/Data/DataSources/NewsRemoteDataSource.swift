//
//  NewsRemoteDataSource.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import Foundation

// MARK: - NewsRemoteDataSource

protocol NewsRemoteDataSource {
    func fetchArticles(query: NewsListQuery) async throws -> NewsResponseDTO
    func fetchArticleDetail(id: String, fetchPolicy: FetchPolicy) async throws -> NewsArticleDTO
    func fetchRelatedArticles(launchID: String, limit: Int, fetchPolicy: FetchPolicy) async throws -> NewsResponseDTO
}

// MARK: - NetworkNewsRemoteDataSource

final class NetworkNewsRemoteDataSource: NewsRemoteDataSource {
    private let networkClient: NetworkClientProtocol

    init(networkClient: NetworkClientProtocol) {
        self.networkClient = networkClient
    }

    func fetchArticles(query: NewsListQuery) async throws -> NewsResponseDTO {
        try await networkClient.request(
            NewsResponseDTO.self,
            endpoint: NewsEndpoint.list(query: query),
            cachePolicy: query.fetchPolicy)
    }

    func fetchArticleDetail(id: String, fetchPolicy: FetchPolicy) async throws -> NewsArticleDTO {
        try await networkClient.request(
            NewsArticleDTO.self,
            endpoint: NewsEndpoint.detail(id: id),
            cachePolicy: fetchPolicy)
    }

    func fetchRelatedArticles(launchID: String, limit: Int, fetchPolicy: FetchPolicy) async throws -> NewsResponseDTO {
        try await networkClient.request(
            NewsResponseDTO.self,
            endpoint: NewsEndpoint.related(launchID: launchID, limit: limit),
            cachePolicy: fetchPolicy)
    }
}

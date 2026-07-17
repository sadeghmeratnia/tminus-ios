//
//  NewsRepository.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import Foundation

// MARK: - NewsRepository

final class NewsRepository: NewsRepositoryProtocol, Sendable {
    private let remoteDataSource: NewsRemoteDataSource

    init(remoteDataSource: NewsRemoteDataSource) {
        self.remoteDataSource = remoteDataSource
    }

    func fetchArticles(query: NewsListQuery) async throws -> PagedResult<NewsArticle> {
        do {
            let response = try await remoteDataSource.fetchArticles(query: query)
            return Self.mapPage(response, query: query)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw NewsErrorMapper.map(error)
        }
    }

    func fetchArticleDetail(id: String) async throws -> NewsArticle {
        do {
            let dto = try await remoteDataSource.fetchArticleDetail(id: id, fetchPolicy: .useCache)
            guard let article = NewsArticleDTOMapper.map(dto) else {
                throw NewsError.decodingFailed
            }
            return article
        } catch is CancellationError {
            throw CancellationError()
        } catch let newsError as NewsError {
            throw newsError
        } catch {
            throw NewsErrorMapper.map(error)
        }
    }

    func fetchRelatedArticles(launchID: String, limit: Int) async throws -> [NewsArticle] {
        do {
            let response = try await remoteDataSource.fetchRelatedArticles(
                launchID: launchID,
                limit: limit,
                fetchPolicy: .useCache
            )
            return response.results.compactMap(NewsArticleDTOMapper.map(_:))
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw NewsErrorMapper.map(error)
        }
    }
}

private extension NewsRepository {
    static func mapPage(_ response: NewsResponseDTO, query: NewsListQuery) -> PagedResult<NewsArticle> {
        PagedResult(
            items: response.results.compactMap(NewsArticleDTOMapper.map(_:)),
            currentPage: query.page,
            totalCount: response.count,
            nextPage: PaginationURLParser.pageNumber(from: response.next, fallbackLimit: query.limit),
            previousPage: PaginationURLParser.pageNumber(from: response.previous, fallbackLimit: query.limit)
        )
    }
}

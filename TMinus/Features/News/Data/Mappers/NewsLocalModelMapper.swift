//
//  NewsLocalModelMapper.swift
//  TMinus
//
//  Created by Sadegh on 13/08/2026.
//

import Foundation

// MARK: - NewsLocalModelMapper

enum NewsLocalModelMapper {
    static func map(_ article: NewsArticle, fetchedAt: Date = .now) -> NewsArticleLocalModel {
        NewsArticleLocalModel(
            id: article.id,
            title: article.title,
            summary: article.summary,
            urlString: article.url.absoluteString,
            imageURLString: article.imageURL?.absoluteString,
            newsSite: article.newsSite,
            publishedAt: article.publishedAt,
            relatedLaunchIDs: article.relatedLaunchIDs,
            fetchedAt: fetchedAt
        )
    }

    /// Updates an existing persisted model in place from a domain entity,
    /// avoiding the allocation of an intermediate model instance.
    static func update(_ model: NewsArticleLocalModel, from article: NewsArticle, fetchedAt: Date) {
        model.title = article.title
        model.titleLowercased = article.title.localizedLowercase
        model.summary = article.summary
        model.urlString = article.url.absoluteString
        model.imageURLString = article.imageURL?.absoluteString
        model.newsSite = article.newsSite
        model.publishedAt = article.publishedAt
        model.relatedLaunchIDs = article.relatedLaunchIDs
        model.fetchedAt = fetchedAt
    }

    /// Returns `nil` only if `urlString` somehow fails to parse back into a `URL`, which
    /// shouldn't happen, since it was already a valid `URL.absoluteString` when persisted, but
    /// `NewsArticle.url` is non-optional so this can't silently substitute a placeholder the way
    /// `Launch`'s optional URL fields can.
    static func map(_ model: NewsArticleLocalModel) -> NewsArticle? {
        guard let url = URL(string: model.urlString) else { return nil }
        return NewsArticle(
            id: model.id,
            title: model.title,
            summary: model.summary,
            url: url,
            imageURL: model.imageURLString.flatMap(URL.init(string:)),
            newsSite: model.newsSite,
            publishedAt: model.publishedAt,
            relatedLaunchIDs: model.relatedLaunchIDs
        )
    }
}

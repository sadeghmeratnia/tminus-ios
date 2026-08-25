//
//  NewsArticleDTOMapper.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import Foundation

enum NewsArticleDTOMapper {
    /// Returns `nil` when the article has no usable link, unlike launch data, news content
    /// is third-party and an article without a valid URL isn't worth surfacing to the user.
    static func map(_ dto: NewsArticleDTO) -> NewsArticle? {
        guard let url = LenientURLDecoding.url(from: dto.url) else { return nil }

        return NewsArticle(
            id: String(dto.id),
            title: dto.title,
            summary: dto.summary,
            url: url,
            imageURL: LenientURLDecoding.url(from: dto.imageURL),
            newsSite: dto.newsSite,
            publishedAt: dto.publishedAt,
            relatedLaunchIDs: dto.launches.map(\.launchID)
        )
    }
}

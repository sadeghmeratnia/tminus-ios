//
//  NewsArticleDTOMapper.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import Foundation

enum NewsArticleDTOMapper {
    /// Returns `nil` when the article has no usable link — unlike launch data, news content
    /// is third-party and an article without a valid URL isn't worth surfacing to the user.
    static func map(_ dto: NewsArticleDTO) -> NewsArticle? {
        guard let url = mapURL(dto.url) else { return nil }

        return NewsArticle(
            id: String(dto.id),
            title: dto.title,
            summary: dto.summary,
            url: url,
            imageURL: dto.imageURL.flatMap(mapURL),
            newsSite: dto.newsSite,
            publishedAt: dto.publishedAt,
            relatedLaunchIDs: dto.launches.map(\.launchID))
    }

    private static func mapURL(_ urlString: String) -> URL? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        if let url = URL(string: trimmed) {
            return url
        }
        let escaped = trimmed.replacingOccurrences(of: " ", with: "%20")
        return URL(string: escaped)
    }
}

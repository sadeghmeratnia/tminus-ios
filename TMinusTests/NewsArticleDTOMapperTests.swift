//
//  NewsArticleDTOMapperTests.swift
//  TMinusTests
//
//  Created by Sadegh on 09/07/2026.
//

import Foundation
import Testing
@testable import TMinus

@Suite("NewsArticleDTOMapper")
enum NewsArticleDTOMapperTests {
    @Test("Maps a well-formed DTO to a domain article")
    static func mapsValidArticle() throws {
        let dto = try decodeArticleDTO(json: """
        {
          "id": 42,
          "title": "Starship reaches orbit",
          "summary": "A short summary.",
          "url": "https://example.com/article",
          "image_url": "https://example.com/image.jpg",
          "news_site": "SpaceNews",
          "published_at": "2026-05-12T10:00:00Z",
          "launches": [{ "launch_id": "launch-1", "provider": "Launch Library 2" }]
        }
        """)

        let article = try #require(NewsArticleDTOMapper.map(dto))

        #expect(article.id == "42")
        #expect(article.title == "Starship reaches orbit")
        #expect(article.url.absoluteString == "https://example.com/article")
        #expect(article.imageURL?.absoluteString == "https://example.com/image.jpg")
        #expect(article.newsSite == "SpaceNews")
        #expect(article.relatedLaunchIDs == ["launch-1"])
    }

    @Test("Returns nil when the article URL is missing")
    static func returnsNilForEmptyURL() throws {
        let dto = try decodeArticleDTO(json: """
        {
          "id": 1,
          "title": "No link",
          "summary": "",
          "url": "",
          "image_url": null,
          "news_site": "SpaceNews",
          "published_at": "2026-05-12T10:00:00Z",
          "launches": []
        }
        """)

        #expect(NewsArticleDTOMapper.map(dto) == nil)
    }

    @Test("Escapes spaces in a malformed URL string")
    static func escapesSpacesInURL() throws {
        let dto = try decodeArticleDTO(json: """
        {
          "id": 2,
          "title": "Spaced URL",
          "summary": "",
          "url": "https://example.com/path with spaces.jpg",
          "image_url": null,
          "news_site": "SpaceNews",
          "published_at": "2026-05-12T10:00:00Z",
          "launches": []
        }
        """)

        let article = try #require(NewsArticleDTOMapper.map(dto))
        #expect(article.url.absoluteString == "https://example.com/path%20with%20spaces.jpg")
    }

    @Test("Ignores image URL when missing without failing the whole mapping")
    static func handlesMissingImageURL() throws {
        let dto = try decodeArticleDTO(json: """
        {
          "id": 3,
          "title": "No image",
          "summary": "",
          "url": "https://example.com/article-3",
          "image_url": null,
          "news_site": "SpaceNews",
          "published_at": "2026-05-12T10:00:00Z",
          "launches": []
        }
        """)

        let article = try #require(NewsArticleDTOMapper.map(dto))
        #expect(article.imageURL == nil)
    }
}

private extension NewsArticleDTOMapperTests {
    static func decodeArticleDTO(json: String) throws -> NewsArticleDTO {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(NewsArticleDTO.self, from: Data(json.utf8))
    }
}

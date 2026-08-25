//
//  NewsArticleDTO.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import Foundation

// MARK: - NewsResponseDTO

/// See `PagedResponseDTO`, the pagination envelope itself (including the "one malformed
/// article must not fail the whole page" behavior) lives there; this is just the
/// `NewsArticleDTO`-specialized name callers use.
typealias NewsResponseDTO = PagedResponseDTO<NewsArticleDTO>

// MARK: - NewsArticleDTO

struct NewsArticleDTO: Decodable {
    let id: Int
    let title: String
    let summary: String
    let url: String
    let imageURL: String?
    let newsSite: String
    let publishedAt: Date
    let launches: [NewsArticleLaunchRefDTO]

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case summary
        case url
        case imageURL = "imageUrl"
        case newsSite
        case publishedAt
        case launches
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        summary = try container.decode(String.self, forKey: .summary)
        url = try container.decode(String.self, forKey: .url)
        imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
        newsSite = try container.decode(String.self, forKey: .newsSite)
        publishedAt = try container.decode(Date.self, forKey: .publishedAt)
        // One malformed related-launch reference (e.g. missing `launch_id`) must not fail
        // decoding of the whole article, see `LossyDecodableArray`.
        let launchRefs = try container.decodeIfPresent(LossyDecodableArray<NewsArticleLaunchRefDTO>.self, forKey: .launches)
        launches = launchRefs?.elements ?? []
    }
}

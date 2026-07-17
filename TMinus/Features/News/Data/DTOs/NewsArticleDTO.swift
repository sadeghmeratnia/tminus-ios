//
//  NewsArticleDTO.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import Foundation

// MARK: - NewsResponseDTO

struct NewsResponseDTO: Decodable {
    let count: Int?
    let next: String?
    let previous: String?
    let results: [NewsArticleDTO]
}

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
}

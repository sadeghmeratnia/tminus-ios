//
//  NewsArticle.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import Foundation

// MARK: - NewsArticle

struct NewsArticle: Equatable, Identifiable {
    let id: String
    let title: String
    let summary: String
    let url: URL
    let imageURL: URL?
    let newsSite: String
    let publishedAt: Date
    let relatedLaunchIDs: [String]
}

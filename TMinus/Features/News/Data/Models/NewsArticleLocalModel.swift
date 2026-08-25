//
//  NewsArticleLocalModel.swift
//  TMinus
//
//  Created by Sadegh on 13/08/2026.
//

import Foundation
import SwiftData

@Model
final class NewsArticleLocalModel {
    @Attribute(.unique) var id: String
    var title: String
    /// See `LaunchLocalModel.nameLowercased`, kept alongside `title` so search uses plain
    /// `String.contains` instead of `.localizedStandardContains`, avoiding a real SIGSEGV in
    /// CoreData/SQLite's ICU-based collation search under concurrent `#Predicate` fetches.
    var titleLowercased: String
    var summary: String
    var urlString: String
    var imageURLString: String?
    var newsSite: String
    var publishedAt: Date
    var relatedLaunchIDs: [String]
    var fetchedAt: Date

    init(id: String,
         title: String,
         summary: String,
         urlString: String,
         imageURLString: String?,
         newsSite: String,
         publishedAt: Date,
         relatedLaunchIDs: [String],
         fetchedAt: Date = .now)
    {
        self.id = id
        self.title = title
        titleLowercased = title.localizedLowercase
        self.summary = summary
        self.urlString = urlString
        self.imageURLString = imageURLString
        self.newsSite = newsSite
        self.publishedAt = publishedAt
        self.relatedLaunchIDs = relatedLaunchIDs
        self.fetchedAt = fetchedAt
    }
}

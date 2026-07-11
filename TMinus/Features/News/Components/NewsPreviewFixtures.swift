//
//  NewsPreviewFixtures.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import Foundation

enum NewsPreviewFixtures {
    static let articleID = "preview-1"

    static let article = NewsArticle(
        id: articleID,
        title: "ispace to send larger payloads to the moon on SpaceX's Starship",
        summary: "Japanese lunar exploration company ispace is buying space on a future Starship lunar lander mission to deliver larger payloads to the moon.",
        url: URL(string: "https://spacenews.com/ispace-to-send-larger-payloads-to-the-moon-on-spacexs-starship/")!,
        imageURL: nil,
        newsSite: "SpaceNews",
        publishedAt: Date(timeIntervalSince1970: 1_735_689_600),
        relatedLaunchIDs: [])

    static let listLoadedState = NewsListState(
        articles: [article],
        searchText: "",
        pagination: .initial,
        phase: .loaded)

    static let detailLoadedState = NewsDetailState(
        articleID: articleID,
        article: article,
        phase: .loaded)
}

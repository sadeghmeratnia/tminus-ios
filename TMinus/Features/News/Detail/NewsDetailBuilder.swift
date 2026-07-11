//
//  NewsDetailBuilder.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import SwiftUI

@MainActor
protocol NewsDetailBuilding {
    func makeView(articleID: String) -> DefaultNewsDetailView
}

@MainActor
final class NewsDetailBuilder: NewsDetailBuilding {
    private let fetchNewsArticleDetailUseCase: FetchNewsArticleDetailUseCase

    init(fetchNewsArticleDetailUseCase: FetchNewsArticleDetailUseCase) {
        self.fetchNewsArticleDetailUseCase = fetchNewsArticleDetailUseCase
    }

    private func makeViewModel(articleID: String) -> NewsDetailViewModel {
        NewsDetailViewModel(
            articleID: articleID,
            fetchNewsArticleDetailUseCase: fetchNewsArticleDetailUseCase)
    }

    func makeView(articleID: String) -> DefaultNewsDetailView {
        NewsDetailView(viewModel: makeViewModel(articleID: articleID))
    }
}

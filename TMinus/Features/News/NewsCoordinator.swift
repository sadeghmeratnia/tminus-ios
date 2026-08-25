//
//  NewsCoordinator.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import SwiftUI

final class NewsCoordinator: StackCoordinator<NewsDestination>, CoordinatorProtocol {
    typealias RootView = NewsRootView

    private let newsListBuilder: NewsListBuilding
    private let newsDetailBuilder: NewsDetailBuilding

    init(newsListBuilder: NewsListBuilding,
         newsDetailBuilder: NewsDetailBuilding)
    {
        self.newsListBuilder = newsListBuilder
        self.newsDetailBuilder = newsDetailBuilder
    }

    func makeRootView() -> NewsRootView {
        NewsRootView(coordinator: self)
    }

    func makeNewsListView(onArticleSelected: @escaping (String) -> Void) -> DefaultNewsListView {
        newsListBuilder.makeView(onArticleSelected: onArticleSelected)
    }

    func showArticleDetail(id: String) {
        push(.articleDetail(id: id))
    }

    @ViewBuilder
    func destinationView(for destination: NewsDestination) -> some View {
        switch destination {
        case let .articleDetail(id):
            newsDetailBuilder.makeView(articleID: id)
        }
    }
}

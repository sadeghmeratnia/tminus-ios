//
//  NewsCoordinator.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import Combine
import SwiftUI

@MainActor
final class NewsCoordinator: ObservableObject, CoordinatorProtocol {
    typealias RootView = NewsRootView

    @Published var path = NavigationPath()

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
        path.append(NewsDestination.articleDetail(id: id))
    }

    @ViewBuilder
    func destinationView(for destination: NewsDestination) -> some View {
        switch destination {
        case let .articleDetail(id):
            newsDetailBuilder.makeView(articleID: id)
        }
    }
}

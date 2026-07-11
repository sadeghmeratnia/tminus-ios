//
//  NewsListBuilder.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import SwiftUI

@MainActor
protocol NewsListBuilding: AnyObject {
    func makeView(onArticleSelected: @escaping (String) -> Void) -> DefaultNewsListView
}

@MainActor
final class NewsListBuilder: NewsListBuilding {
    private let viewModel: NewsListViewModel

    init(viewModel: NewsListViewModel) {
        self.viewModel = viewModel
    }

    func makeView(onArticleSelected: @escaping (String) -> Void) -> DefaultNewsListView {
        NewsListView(viewModel: viewModel, onArticleSelected: onArticleSelected)
    }
}

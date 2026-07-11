//
//  NewsRootView.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import SwiftUI

struct NewsRootView: View {
    @ObservedObject private var coordinator: NewsCoordinator

    init(coordinator: NewsCoordinator) {
        self.coordinator = coordinator
    }

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            coordinator.makeNewsListView(onArticleSelected: coordinator.showArticleDetail(id:))
                .navigationDestination(for: NewsDestination.self) { destination in
                    coordinator.destinationView(for: destination)
                }
        }
    }
}

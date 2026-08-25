//
//  NewsFeatureBuilderTests.swift
//  TMinusTests
//
//  Created by Sadegh on 13/07/2026.
//

import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import TMinus

@MainActor
@Suite("NewsFeatureBuilder")
struct NewsFeatureBuilderTests {
    @Test("makeCoordinator wires a working NewsCoordinator")
    func makeCoordinatorWiresCoordinator() throws {
        let builder = NewsFeatureBuilder(dependencies: try Self.makeDependencies())

        let coordinator = builder.makeCoordinator()

        #expect(coordinator.path.isEmpty)
        _ = coordinator.makeRootView()
    }

    @Test("Each call to makeCoordinator produces an independent coordinator")
    func makeCoordinatorProducesIndependentInstances() throws {
        let builder = NewsFeatureBuilder(dependencies: try Self.makeDependencies())

        let first = builder.makeCoordinator()
        let second = builder.makeCoordinator()

        first.showArticleDetail(id: "article-1")

        #expect(first.path.count == 1)
        #expect(second.path.isEmpty)
    }

    @Test("makeRepository is reusable so other features can share it")
    func makeRepositoryIsUsableIndependently() async throws {
        let builder = NewsFeatureBuilder(dependencies: try Self.makeDependencies())

        let repository = builder.makeRepository()

        // NoopNetworkClient always throws and the local cache starts empty, this just proves
        // the repository is wired to the injected network client rather than crashing or
        // silently no-op'ing, mirroring how LaunchesFeatureBuilder consumes this exact repository
        // for its Related News use case.
        await #expect(throws: NetworkFeatureError.self) {
            try await repository.fetchArticles(query: NewsListQuery(fetchPolicy: .networkOnly))
        }
    }
}

private extension NewsFeatureBuilderTests {
    static func makeDependencies() throws -> NewsFeatureBuilder.Dependencies {
        let schema = Schema([NewsArticleLocalModel.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let modelContainer = try ModelContainer(for: schema, configurations: [configuration])

        return NewsFeatureBuilder.Dependencies(
            networkClient: NoopNetworkClient(),
            modelContainer: modelContainer
        )
    }
}

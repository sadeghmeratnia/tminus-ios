//
//  LaunchesFeatureBuilderTests.swift
//  TMinusTests
//
//  Created by Sadegh on 13/07/2026.
//

@testable import TMinus
import Testing
import Foundation
import SwiftData
import SwiftUI

@MainActor
@Suite("LaunchesFeatureBuilder")
struct LaunchesFeatureBuilderTests {
    @Test("makeCoordinator wires a working LaunchesCoordinator")
    func makeCoordinatorWiresCoordinator() throws {
        let builder = LaunchesFeatureBuilder(dependencies: try Self.makeDependencies())

        let coordinator = builder.makeCoordinator()

        #expect(coordinator.path.isEmpty)
        _ = coordinator.makeRootView()
    }

    @Test("Each call to makeCoordinator produces an independent coordinator")
    func makeCoordinatorProducesIndependentInstances() throws {
        let builder = LaunchesFeatureBuilder(dependencies: try Self.makeDependencies())

        let first = builder.makeCoordinator()
        let second = builder.makeCoordinator()

        first.showLaunchDetail(id: "launch-1")

        #expect(first.path.count == 1)
        #expect(second.path.isEmpty)
    }
}

extension LaunchesFeatureBuilderTests {
    fileprivate static func makeDependencies() throws -> LaunchesFeatureBuilder.Dependencies {
        let schema = Schema([LaunchLocalModel.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let modelContainer = try ModelContainer(for: schema, configurations: [configuration])

        return LaunchesFeatureBuilder.Dependencies(
            networkClient: NoopNetworkClient(),
            modelContainer: modelContainer,
            newsRepository: MockNewsRepository())
    }
}

// MARK: - NoopNetworkClient

/// A network client that never actually issues a request — sufficient for builder/coordinator
/// wiring tests, which only need the dependency graph to construct, not to fetch real data.
final class NoopNetworkClient: NetworkClientProtocol, Sendable {
    func requestData(endpoint: Endpoint, cachePolicy: FetchPolicy) async throws -> Data {
        throw NetworkError.invalidResponse
    }

    func request<T>(_ type: T.Type, endpoint: Endpoint, cachePolicy: FetchPolicy) async throws -> T where T: Decodable & Sendable {
        throw NetworkError.invalidResponse
    }
}

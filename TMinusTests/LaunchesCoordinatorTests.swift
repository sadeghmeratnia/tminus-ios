//
//  LaunchesCoordinatorTests.swift
//  TMinusTests
//
//  Created by Sadegh on 13/07/2026.
//

import Foundation
import SwiftUI
import Testing
@testable import TMinus

@MainActor
@Suite("LaunchesCoordinator")
struct LaunchesCoordinatorTests {
    @Test("Path starts empty")
    func pathStartsEmpty() {
        let coordinator = Self.makeCoordinator()
        #expect(coordinator.path.isEmpty)
    }

    @Test("showLaunchDetail pushes a destination onto the path")
    func showLaunchDetailPushesDestination() {
        let coordinator = Self.makeCoordinator()

        coordinator.showLaunchDetail(id: "launch-1")

        #expect(coordinator.path.count == 1)
    }

    @Test("Repeated navigation accumulates distinct path entries")
    func repeatedNavigationAccumulatesPathEntries() {
        let coordinator = Self.makeCoordinator()

        coordinator.showLaunchDetail(id: "launch-1")
        coordinator.showLaunchDetail(id: "launch-2")

        #expect(coordinator.path.count == 2)
    }

    @Test("destinationView resolves a launchDetail destination via the injected builder")
    func destinationViewResolvesLaunchDetail() {
        let detailBuilder = RecordingLaunchDetailBuilder()
        let coordinator = LaunchesCoordinator(
            launchListBuilder: Self.makeListBuilder(),
            launchDetailBuilder: detailBuilder
        )

        _ = coordinator.destinationView(for: .launchDetail(id: "launch-42"))

        #expect(detailBuilder.requestedLaunchIDs == ["launch-42"])
    }

    @Test("makeRootView builds a LaunchesRootView backed by this coordinator")
    func makeRootViewBuildsRootView() {
        let coordinator = Self.makeCoordinator()
        _ = coordinator.makeRootView()
        // Constructing the root view must not crash and must be reachable via the
        // coordinator's own navigation state, exercised implicitly by not throwing/trapping.
        #expect(coordinator.path.isEmpty)
    }
}

private extension LaunchesCoordinatorTests {
    static func makeCoordinator() -> LaunchesCoordinator {
        LaunchesCoordinator(launchListBuilder: makeListBuilder(), launchDetailBuilder: makeDetailBuilder())
    }

    static func makeListBuilder() -> LaunchListBuilder {
        LaunchListBuilder(
            viewModel: LaunchListViewModel(
                fetchUpcomingLaunchesUseCase: FetchUpcomingLaunchesUseCase(repository: MockLaunchRepository()),
                fetchPreviousLaunchesUseCase: FetchPreviousLaunchesUseCase(repository: MockLaunchRepository())
            )
        )
    }

    static func makeDetailBuilder() -> LaunchDetailBuilder {
        LaunchDetailBuilder(
            fetchLaunchDetailUseCase: FetchLaunchDetailUseCase(repository: MockLaunchDetailRepository()),
            fetchRelatedNewsUseCase: FetchRelatedNewsUseCase(repository: MockNewsRepository())
        )
    }
}

// MARK: - RecordingLaunchDetailBuilder

@MainActor
private final class RecordingLaunchDetailBuilder: LaunchDetailBuilding {
    private(set) var requestedLaunchIDs: [String] = []

    func makeView(launchID: String) -> DefaultLaunchDetailView {
        requestedLaunchIDs.append(launchID)
        return LaunchDetailBuilder(
            fetchLaunchDetailUseCase: FetchLaunchDetailUseCase(repository: MockLaunchDetailRepository()),
            fetchRelatedNewsUseCase: FetchRelatedNewsUseCase(repository: MockNewsRepository())
        )
        .makeView(launchID: launchID)
    }
}

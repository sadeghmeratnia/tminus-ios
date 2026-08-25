//
//  AppCoordinator.swift
//  TMinus
//
//  Created by Sadegh on 07/05/2026.
//

import SwiftUI

@MainActor
final class AppCoordinator: CoordinatorProtocol {
    typealias RootView = AppRootView

    private let newsCoordinator: NewsCoordinator
    private let launchesCoordinator: LaunchesCoordinator
    /// Constructed once, here, rather than inside `rootView()`, a `NetworkImageDataLoader`
    /// allocated fresh on every `rootView()` call would give `.environment(\.imageDataLoader, ...)`
    /// a new identity on every call, which is harmless today only because nothing currently
    /// triggers a second call while `.ready`, not because a fresh instance is actually needed.
    private let imageDataLoader: NetworkImageDataLoader

    /// Built explicitly, in order, rather than via `lazy var`s that reference one another,
    /// Launches needs News's shared repository (for its related-articles section), so News is
    /// built first and its repository handed to Launches as a constructor argument. That
    /// dependency is a plain step here instead of something the compiler has to resolve for us
    /// via lazy-property evaluation order.
    init(container: AppContainer) {
        imageDataLoader = NetworkImageDataLoader(networkClient: container.imageNetworkClient)

        let newsFeatureBuilder = NewsFeatureBuilder(
            dependencies: NewsFeatureBuilder.Dependencies(
                networkClient: container.networkClient,
                modelContainer: container.modelContainer
            )
        )
        newsCoordinator = newsFeatureBuilder.makeCoordinator()

        let launchesFeatureBuilder = LaunchesFeatureBuilder(
            dependencies: LaunchesFeatureBuilder.Dependencies(
                networkClient: container.networkClient,
                modelContainer: container.modelContainer,
                relatedNewsProvider: newsFeatureBuilder.makeRepository()
            )
        )
        launchesCoordinator = launchesFeatureBuilder.makeCoordinator()
    }

    func makeRootView() -> AppRootView {
        AppRootView(
            launchesRootView: launchesCoordinator.makeRootView(),
            newsRootView: newsCoordinator.makeRootView()
        )
    }
}

extension AppCoordinator {
    /// Applied once at the root so every `RemoteImagePhaseView` in the hierarchy loads through
    /// the app's own `NetworkClientProtocol` (and therefore `DataCache`) instead of the
    /// preview/test-only `URLSession.shared` fallback `EnvironmentValues.imageDataLoader`
    /// defaults to.
    func rootView() -> some View {
        makeRootView()
            .environment(\.imageDataLoader, imageDataLoader)
    }
}

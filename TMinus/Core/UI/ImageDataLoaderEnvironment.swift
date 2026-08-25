//
//  ImageDataLoaderEnvironment.swift
//  TMinus
//
//  Created by Sadegh on 16/08/2026.
//

import SwiftUI
import UIKit

// MARK: - EnvironmentValues

extension EnvironmentValues {
    /// Set at the app root (`AppCoordinator.makeRootView()`) to a `NetworkImageDataLoader`
    /// wrapping the shared `NetworkClientProtocol`, so every `RemoteImagePhaseView` shares the
    /// same cache/retry/logging path as the rest of the app. The default below only backs
    /// previews and tests, which have no `AppContainer` to source one from, it deliberately
    /// bypasses `DataCache` for that reason, and must never be reached in the running app.
    var imageDataLoader: ImageDataLoading {
        get { self[ImageDataLoaderKey.self] }
        set { self[ImageDataLoaderKey.self] = newValue }
    }
}

// MARK: - ImageDataLoaderKey

private struct ImageDataLoaderKey: EnvironmentKey {
    static let defaultValue: ImageDataLoading = URLSessionImageDataLoader()
}

// MARK: - URLSessionImageDataLoader

/// Preview/test-only fallback, see `EnvironmentValues.imageDataLoader`.
private struct URLSessionImageDataLoader: ImageDataLoading {
    func data(for url: URL) async throws -> Data {
        // `AppCoordinator.rootView()` always overrides this environment value at the app root,
        // so reaching this fallback in a real run means that injection was missed, fail loudly
        // in DEBUG rather than silently degrading to an uncached, unretried, unlogged network
        // path. Previews and tests are expected to reach here, so they're excluded.
        assert(
            Self.isPreviewOrTest,
            "URLSessionImageDataLoader reached outside of a preview/test — \\.imageDataLoader was never overridden."
        )
        return try await URLSession.shared.data(from: url).0
    }

    private static var isPreviewOrTest: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            || NSClassFromString("XCTestCase") != nil
    }
}

// MARK: - PreviewImageDataLoader

#if DEBUG
    /// A local, network-free `ImageDataLoading` for any `#Preview` that passes a non-nil
    /// `imageURL`, without this, such a preview falls through to `URLSessionImageDataLoader`
    /// above, which performs a real, uncached `URLSession.shared` request against whatever URL
    /// the preview happens to use (typically a placeholder like `example.com` that serves no
    /// actual image), making the preview canvas dependent on network reachability and
    /// non-hermetic for no reason a preview should ever need. Set via
    /// `.environment(\.imageDataLoader, PreviewImageDataLoader())` on the specific `#Preview`s
    /// that need it (e.g. `HeroImageView`'s and `MediaCardView`'s "With image" previews).
    struct PreviewImageDataLoader: ImageDataLoading {
        func data(for _: URL) async throws -> Data {
            let renderer = UIGraphicsImageRenderer(size: Constants.size)
            return renderer.pngData { context in
                UIColor.systemGray3.setFill()
                context.fill(CGRect(origin: .zero, size: Constants.size))
            }
        }

        private enum Constants {
            static let size = CGSize(width: 64, height: 64)
        }
    }
#endif

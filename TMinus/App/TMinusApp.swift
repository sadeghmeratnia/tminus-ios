//
//  TMinusApp.swift
//  TMinus
//
//  Created by Sadegh on 22/04/2026.
//

import os
import SwiftData
import SwiftUI
import UIKit

// MARK: - TMinusApp

@main
struct TMinusApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var launchState: LaunchState = .launching
    // Bumped to re-trigger `.task(id:)` on retry, `.task` only reruns when its `id` changes, so
    // a plain `onRetry: { launchState = .launching }` wouldn't restart the bootstrap work itself.
    @State private var launchAttempt = 0

    var body: some Scene {
        WindowGroup {
            content
                // Bootstrap (directory creation + `ModelContainer` init, including the
                // delete-and-recreate corruption-recovery path) does real disk I/O and previously
                // ran synchronously on the main thread, both at cold launch and on every retry
                // tap, blocking the UI with no feedback on a slow/near-full disk, on exactly the
                // failure path this is meant to recover from. Running it off the main actor and
                // showing `.launching` while it's in flight fixes both.
                .task(id: launchAttempt) {
                    launchState = .launching
                    launchState = await Self.makeLaunchState()
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .background, case let .ready(_, caches) = launchState else { return }
            Self.sweepCacheInBackground(caches)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch launchState {
        case let .ready(appCoordinator, _):
            appCoordinator.rootView()
        case .launching:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed:
            AppLaunchFailureView { launchAttempt += 1 }
        }
    }
}

// MARK: - LaunchState

extension TMinusApp {
    /// Bootstrap either produces a working dependency graph or it doesn't, modeled as an enum
    /// (rather than optionals) so `body` can't accidentally read `appCoordinator`/`cache` from a
    /// bootstrap that failed.
    enum LaunchState {
        case launching
        /// Both `DataCache` instances the container owns, `AppContainer.cache` (JSON) and
        /// `AppContainer.imageCache` (images), so a background transition sweeps both instead
        /// of leaving the image cache's stale entries to linger until `NSCache` evicts them
        /// under memory pressure.
        case ready(AppCoordinator, [DataCache])
        case failed
    }

    /// The plain unstructured `Task` this replaced had no protection against the process being
    /// suspended shortly after backgrounding, a fast background-then-suspend transition could
    /// cut the sweep off mid-pass. Wrapping it in a `beginBackgroundTask` assertion asks iOS for
    /// a little extra runway to finish; it's still best-effort (the OS can revoke the assertion
    /// under memory pressure), but this is the standard way to make that best effort real rather
    /// than purely nominal.
    static func sweepCacheInBackground(_ caches: [DataCache]) {
        var taskID: UIBackgroundTaskIdentifier = .invalid
        // Guards against ending the same `taskID` twice: the OS can invoke the expiration
        // handler concurrently with (or just before) the sweep `Task` finishing on its own, and
        // `UIApplication.endBackgroundTask` being called twice for one identifier is an
        // over-release the system logs as a runtime warning and, on some OS versions, asserts on.
        let hasEnded = OSAllocatedUnfairLock(initialState: false)
        func endOnce() {
            let shouldEnd = hasEnded.withLock { ended in
                defer { ended = true }
                return ended == false
            }
            // `.invalid` means the OS never started a background task assertion, so there's
            // nothing to balance with `endBackgroundTask`, calling it anyway isn't documented
            // as safe and isn't needed.
            if shouldEnd, taskID != .invalid {
                UIApplication.shared.endBackgroundTask(taskID)
            }
        }
        taskID = UIApplication.shared.beginBackgroundTask(withName: "DataCache.removeStaleEntries") {
            endOnce()
        }
        // Even if the OS declined to hand out a valid identifier (e.g. background time budget
        // already exhausted), still attempt the sweep best-effort rather than skipping it
        // outright, worst case it gets suspended mid-pass, same as before this assertion existed.
        Task {
            for cache in caches {
                await cache.removeStaleEntries()
            }
            endOnce()
        }
    }

    /// Runs off the main actor so the synchronous disk I/O in `bootstrap()` never blocks the UI,
    /// see the doc comment on `TMinusApp.body`'s `.task` for why that matters on the retry path
    /// specifically.
    @concurrent
    static func makeLaunchState() async -> LaunchState {
        do {
            let container = try bootstrap()
            let appCoordinator = await AppCoordinator(container: container)
            return .ready(appCoordinator, [container.cache, container.imageCache])
        } catch {
            OSNetworkLogger().log("✖ App bootstrap failed: \(error)", level: .error)
            return .failed
        }
    }
}

extension TMinusApp {
    /// Explicitly `nonisolated`, `TMinusApp` is otherwise inferred main-actor-isolated (it
    /// conforms to `App`), and this does blocking disk I/O (`ModelContainer` init) that
    /// `makeLaunchState()` specifically runs off the main actor to keep the UI responsive; without
    /// this it would silently hop back onto the main actor and defeat that.
    nonisolated static func bootstrap() throws -> AppContainer {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .flexibleISO8601

        let logger = OSNetworkLogger()
        let cache = DataCache()
        // See `AppContainer.imageCache`'s doc comment, a separate `DataCache` so image traffic
        // can't evict fresher JSON responses out of a shared budget.
        let imageCache = DataCache()

        let networkClient = URLSessionNetworkClient(
            session: URLSession.appNetworking,
            decoder: decoder,
            retryPolicy: DefaultRetryPolicy(),
            logger: logger,
            cache: cache
        )
        let imageNetworkClient = URLSessionNetworkClient(
            session: URLSession.appNetworking,
            decoder: decoder,
            retryPolicy: DefaultRetryPolicy(),
            logger: logger,
            cache: imageCache
        )

        let schema = Schema([
            LaunchLocalModel.self,
            NewsArticleLocalModel.self,
        ])
        let storeURL = URL.applicationSupportDirectory.appending(path: "TMinus.store")
        // `~/Library/Application Support` isn't guaranteed to exist on a fresh install, without
        // creating it up front, `ModelContainer` init below can fail on the very first launch
        // with "no such file or directory," and the existing corruption-recovery retry in
        // `makeModelContainer` wouldn't help (it deletes files that were never there and retries
        // the same configuration, which fails for the same reason).
        try FileManager.default.createDirectory(
            at: storeURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        let modelContainer = try makeModelContainer(schema: schema, configuration: configuration, storeURL: storeURL, logger: logger)

        return AppContainer(
            networkClient: networkClient,
            imageNetworkClient: imageNetworkClient,
            modelContainer: modelContainer,
            cache: cache,
            imageCache: imageCache
        )
    }

    /// The local store is a cache of remote data, not a source of truth, so a corrupted or
    /// unmigratable on-disk store (schema mismatch after an update, disk corruption, etc.) is
    /// recovered from by discarding it and starting fresh, rather than crashing the app on
    /// every subsequent launch.
    nonisolated static func makeModelContainer(schema: Schema,
                                   configuration: ModelConfiguration,
                                   storeURL: URL,
                                   logger: OSNetworkLogger = OSNetworkLogger()) throws -> ModelContainer
    {
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            logger.log("✖ ModelContainer creation failed, resetting local store: \(error)", level: .error)
            try? FileManager.default.removeItem(at: storeURL)
            // SQLite's WAL-mode sidecar files are named by *suffixing* the full filename
            // ("TMinus.store-shm"/"-wal"), not by replacing/adding a dot extension
            // ("TMinus.store.shm" is a different, nonexistent path), `appendingPathExtension`
            // would silently fail to remove them, leaving stale journal data next to the freshly
            // recreated store.
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path + "-shm"))
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path + "-wal"))
            return try ModelContainer(for: schema, configurations: [configuration])
        }
    }
}

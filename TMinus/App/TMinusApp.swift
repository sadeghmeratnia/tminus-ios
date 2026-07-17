//
//  TMinusApp.swift
//  TMinus
//
//  Created by Sadegh on 22/04/2026.
//

import SwiftUI
import SwiftData

// MARK: - TMinusApp

@main
struct TMinusApp: App {
    @Environment(\.scenePhase) private var scenePhase

    private let appCoordinator: AppCoordinator
    private let cache: DataCache

    init() {
        do {
            let container = try Self.bootstrap()
            self.appCoordinator = AppCoordinator(container: container)
            self.cache = container.cache
        } catch {
            fatalError("Failed to bootstrap app: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            appCoordinator.makeRootView()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .background else { return }
            Task { await cache.removeStaleEntries() }
        }
    }
}

extension TMinusApp {
    fileprivate static func bootstrap() throws -> AppContainer {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        let logger = OSNetworkLogger()
        let cache = DataCache()

        let networkClient = URLSessionNetworkClient(
            session: URLSession.shared,
            decoder: decoder,
            retryPolicy: DefaultRetryPolicy(),
            logger: logger,
            cache: cache)

        let schema = Schema([
            LaunchLocalModel.self,
        ])
        let storeURL = URL.applicationSupportDirectory.appending(path: "TMinus.store")
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        let modelContainer = try makeModelContainer(schema: schema, configuration: configuration, storeURL: storeURL)

        return AppContainer(
            networkClient: networkClient,
            modelContainer: modelContainer,
            cache: cache,
            logger: logger)
    }

    /// The local store is a cache of remote data, not a source of truth, so a corrupted or
    /// unmigratable on-disk store (schema mismatch after an update, disk corruption, etc.) is
    /// recovered from by discarding it and starting fresh, rather than crashing the app on
    /// every subsequent launch.
    fileprivate static func makeModelContainer(schema: Schema,
                                                configuration: ModelConfiguration,
                                                storeURL: URL) throws -> ModelContainer {
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            let logger = OSNetworkLogger()
            logger.log("✖ ModelContainer creation failed, resetting local store: \(error)", level: .error)
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
            return try ModelContainer(for: schema, configurations: [configuration])
        }
    }
}

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
    private let appCoordinator: AppCoordinator

    init() {
        do {
            let container = try Self.bootstrap()
            self.appCoordinator = AppCoordinator(container: container)
        } catch {
            fatalError("Failed to bootstrap app: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            appCoordinator.makeRootView()
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
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let modelContainer = try ModelContainer(for: schema, configurations: [configuration])

        return AppContainer(
            networkClient: networkClient,
            modelContainer: modelContainer,
            cache: cache,
            logger: logger)
    }
}

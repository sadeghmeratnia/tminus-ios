//
//  AppContainer.swift
//  TMinus
//
//  Created by Sadegh on 22/04/2026.
//

import Foundation
import SwiftData

final class AppContainer {
    let networkClient: NetworkClientProtocol
    let modelContainer: ModelContainer
    let cache: DataCache
    let logger: NetworkLogger

    init(networkClient: NetworkClientProtocol,
         modelContainer: ModelContainer,
         cache: DataCache,
         logger: NetworkLogger)
    {
        self.networkClient = networkClient
        self.modelContainer = modelContainer
        self.cache = cache
        self.logger = logger
    }

    #if DEBUG
        static func preview() -> AppContainer {
            let logger = OSNetworkLogger()
            let cache = DataCache()
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601

            let networkClient = URLSessionNetworkClient(
                session: URLSession.shared,
                decoder: decoder,
                retryPolicy: DefaultRetryPolicy(),
                logger: logger,
                cache: cache
            )

            let schema = Schema([LaunchLocalModel.self])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            let modelContainer: ModelContainer
            do {
                modelContainer = try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                fatalError("Failed to bootstrap preview container: \(error)")
            }

            return AppContainer(
                networkClient: networkClient,
                modelContainer: modelContainer,
                cache: cache,
                logger: logger
            )
        }
    #endif
}

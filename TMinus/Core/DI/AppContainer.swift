//
//  AppContainer.swift
//  TMinus
//
//  Created by Sadegh on 22/04/2026.
//

import Foundation
import SwiftData

/// `NetworkLogger` is deliberately not stored here, every consumer either already has it baked
/// into `networkClient` (constructed with it above this container) or instantiates its own
/// private, category-scoped `Logger` (`LaunchRepository`, `NewsRepository`), so a container-level
/// copy would be a pass-through nothing reads.
final class AppContainer {
    let networkClient: NetworkClientProtocol
    /// Backed by its own `DataCache` (`imageCache`), separate from `networkClient`'s, see
    /// `imageCache`'s doc comment for why sharing one budget between images and JSON responses
    /// is a real correctness/perf concern, not just tidiness.
    let imageNetworkClient: NetworkClientProtocol
    let modelContainer: ModelContainer
    let cache: DataCache
    /// A dedicated `DataCache` for `imageNetworkClient` rather than reusing `cache`. Images are
    /// cached far longer than JSON (24h vs. ~5min, see `NetworkImageDataLoader`) and tend to be
    /// much larger per-entry; sharing one `NSCache` budget between the two let scrolling an
    /// image-heavy list evict recently-fetched, still-fresh JSON list/detail responses well
    /// before their own TTL, forcing avoidable re-fetches purely because of image traffic.
    let imageCache: DataCache

    init(networkClient: NetworkClientProtocol,
         imageNetworkClient: NetworkClientProtocol,
         modelContainer: ModelContainer,
         cache: DataCache,
         imageCache: DataCache)
    {
        self.networkClient = networkClient
        self.imageNetworkClient = imageNetworkClient
        self.modelContainer = modelContainer
        self.cache = cache
        self.imageCache = imageCache
    }

    #if DEBUG
        static func preview() -> AppContainer {
            let logger = OSNetworkLogger()
            let cache = DataCache()
            let imageCache = DataCache()
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .flexibleISO8601

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

            let schema = Schema([LaunchLocalModel.self, NewsArticleLocalModel.self])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            let modelContainer: ModelContainer
            do {
                modelContainer = try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                fatalError("Failed to bootstrap preview container: \(error)")
            }

            return AppContainer(
                networkClient: networkClient,
                imageNetworkClient: imageNetworkClient,
                modelContainer: modelContainer,
                cache: cache,
                imageCache: imageCache
            )
        }
    #endif
}

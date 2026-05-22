//
//  ContentView.swift
//  TMinus
//
//  Created by Sadegh on 22/04/2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @ObservedObject var viewModel: LaunchListViewModel

    var body: some View {
        LaunchListView(viewModel: viewModel)
    }
}

#Preview {
    let schema = Schema([LaunchLocalModel.self])
    let configuration = try! ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let modelContainer = try! ModelContainer(for: schema, configurations: [configuration])

    let logger = OSNetworkLogger()
    let cache = DataCache()

    let networkClient = URLSessionNetworkClient(
        baseURL: APIEnvironment.current.launchLibraryBaseURL,
        session: URLSession.shared,
        decoder: {
            let d = JSONDecoder()
            d.keyDecodingStrategy = .convertFromSnakeCase
            d.dateDecodingStrategy = .iso8601
            return d
        }(),
        retryPolicy: DefaultRetryPolicy(),
        logger: logger,
        cache: cache)

    let container = AppContainer(
        networkClient: networkClient,
        modelContainer: modelContainer,
        cache: cache,
        logger: logger)

    let builder = LaunchesFeatureBuilder(container: container)
    let coordinator = builder.makeCoordinator()
    coordinator.makeRootView()
}

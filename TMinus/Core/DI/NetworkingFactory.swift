//
//  NetworkingFactory.swift
//  TMinus
//
//  Created by Sadegh on 23/04/2026.
//

import Foundation

final class NetworkingFactory {
    let networkClient: NetworkClientProtocol

    init(apiEnvironment: APIEnvironment) {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        self.networkClient = URLSessionNetworkClient(
            baseURL: apiEnvironment.launchLibraryBaseURL,
            session: URLSession.shared,
            decoder: decoder,
            retryPolicy: DefaultRetryPolicy(),
            logger: OSNetworkLogger())
    }
}

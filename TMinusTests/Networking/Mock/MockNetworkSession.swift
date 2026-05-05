//
//  MockNetworkSession.swift
//  TMinus
//
//  Created by Sadegh on 05/05/2026.
//

import Foundation
@testable import TMinus

final class MockNetworkSession: NetworkSession {
    typealias Handler = (URLRequest) throws -> (Data, URLResponse)

    private let handler: Handler

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try handler(request)
    }
}

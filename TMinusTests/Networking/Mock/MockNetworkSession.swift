//
//  MockNetworkSession.swift
//  TMinus
//
//  Created by Sadegh on 05/05/2026.
//

import Foundation
@testable import TMinus

final class MockNetworkSession: NetworkSession, Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> (Data, URLResponse)
    typealias AsyncHandler = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    private let handler: AsyncHandler

    init(handler: @escaping Handler) {
        self.handler = { try handler($0) }
    }

    init(asyncHandler: @escaping AsyncHandler) {
        handler = asyncHandler
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await handler(request)
    }
}

//
//  Helpers.swift
//  TMinusTests
//
//  Created by Sadegh on 05/05/2026.
//

import Foundation
@testable import TMinus

extension HTTPURLResponse {
    static func make(
        url: URL = URL(string: "https://example.com")!,
        statusCode: Int
    ) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }
}

extension Endpoint {
    static var mock: Endpoint {
        Endpoint(path: "mock")
    }
}

//
//  NetworkError.swift
//  TMinus
//
//  Created by Sadegh on 22/04/2026.
//

import Foundation

// MARK: - NetworkError

enum NetworkError: Error {
    case invalidURL
    case requestEncoding
    case invalidResponse
    case statusCode(Int)
    case transport(URLError)
    case decoding(Error)
    case unknown(underlying: Error)
}

extension NetworkError {
    var userMessage: String {
        switch self {
        case .invalidURL, .requestEncoding:
            return L10n.Error.Network.requestCreation
        case .invalidResponse:
            return L10n.Error.Network.invalidResponse
        case let .statusCode(code):
            if code == 401 || code == 403 {
                return L10n.Error.Network.unauthorized
            }
            if code == 429 {
                return L10n.Error.Network.rateLimited
            }
            if code >= 500 {
                return L10n.Error.Network.serverUnavailable
            }
            return L10n.Error.Network.genericLoad
        case .transport:
            return L10n.Error.Network.transport
        case .decoding:
            return L10n.Error.Network.decoding
        case .unknown:
            return L10n.Error.Network.unknown
        }
    }
}

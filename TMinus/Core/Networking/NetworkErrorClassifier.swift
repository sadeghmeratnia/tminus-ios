//
//  NetworkErrorClassifier.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import Foundation

// MARK: - NetworkErrorClassification

enum NetworkErrorClassification: Sendable {
    case networkUnavailable
    case unauthorized
    case rateLimited
    case serverError
    case decodingFailed
    case unknown(underlying: any Error & Sendable)
}

// MARK: - NetworkErrorClassifier

enum NetworkErrorClassifier {
    static func classify(_ error: Error) -> NetworkErrorClassification {
        guard let networkError = error as? NetworkError else {
            return .unknown(underlying: UncheckedSendableError(error))
        }

        switch networkError {
        case .transport:
            return .networkUnavailable
        case let .statusCode(code) where code == 401 || code == 403:
            return .unauthorized
        case let .statusCode(code) where code == 429:
            return .rateLimited
        case let .statusCode(code) where code >= 500:
            return .serverError
        case .decoding:
            return .decodingFailed
        default:
            return .unknown(underlying: networkError)
        }
    }
}

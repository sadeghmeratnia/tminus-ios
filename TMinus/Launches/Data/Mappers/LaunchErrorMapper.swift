//
//  LaunchErrorMapper.swift
//  TMinus
//
//  Created by Sadegh on 22/05/2026.
//

import Foundation

enum LaunchErrorMapper {
    static func map(_ error: Error) -> LaunchError {
        guard let networkError = error as? NetworkError else {
            return .unknown(underlying: error)
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

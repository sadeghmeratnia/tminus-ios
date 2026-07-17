//
//  LaunchErrorMapper.swift
//  TMinus
//
//  Created by Sadegh on 22/05/2026.
//

import Foundation

enum LaunchErrorMapper {
    static func map(_ error: Error) -> LaunchError {
        switch NetworkErrorClassifier.classify(error) {
        case .networkUnavailable:
            return .networkUnavailable
        case .unauthorized:
            return .unauthorized
        case .rateLimited:
            return .rateLimited
        case .serverError:
            return .serverError
        case .decodingFailed:
            return .decodingFailed
        case let .unknown(underlying):
            return .unknown(underlying: ErrorSummary(underlying))
        }
    }
}

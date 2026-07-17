//
//  NewsErrorMapper.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import Foundation

enum NewsErrorMapper {
    static func map(_ error: Error) -> NewsError {
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

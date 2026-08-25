//
//  NetworkFeatureError.swift
//  TMinus
//
//  Created by Sadegh on 13/08/2026.
//

import Foundation

/// The user-facing error shape for any feature whose data ultimately comes over the network,
/// shared by Launches and News rather than each declaring its own byte-for-byte-identical enum.
/// Both features' errors were always just `NetworkErrorClassifier`'s classification wearing a
/// feature-specific name; this is that same classification with one name, one mapper, and one
/// `UserMessagePresentable` conformance instead of two of each.
enum NetworkFeatureError: Error, Equatable {
    case networkUnavailable
    case timeout
    case unauthorized
    case rateLimited
    case serverError
    case clientError(statusCode: Int)
    case decodingFailed
    case unknown(underlying: ErrorSummary)

    static func map(_ error: Error) -> NetworkFeatureError {
        switch NetworkErrorClassifier.classify(error) {
        case .networkUnavailable:
            .networkUnavailable
        case .timeout:
            .timeout
        case .unauthorized:
            .unauthorized
        case .rateLimited:
            .rateLimited
        case .serverError:
            .serverError
        case let .clientError(statusCode):
            .clientError(statusCode: statusCode)
        case .decodingFailed:
            .decodingFailed
        case let .unknown(underlying):
            .unknown(underlying: underlying)
        }
    }
}

// MARK: - UserMessagePresentable

extension NetworkFeatureError: UserMessagePresentable {
    var userMessage: String {
        switch self {
        case .networkUnavailable:
            L10n.Error.Network.transport
        case .timeout:
            L10n.Error.Network.timeout
        case .unauthorized:
            L10n.Error.Network.unauthorized
        case .rateLimited:
            L10n.Error.Network.rateLimited
        case .serverError:
            L10n.Error.Network.serverUnavailable
        case .clientError:
            L10n.Error.Network.clientError
        case .decodingFailed:
            L10n.Error.Network.decoding
        case .unknown:
            L10n.Error.Network.unknown
        }
    }
}

//
//  LaunchError.swift
//  TMinus
//
//  Created by Sadegh on 22/05/2026.
//

import Foundation

enum LaunchError: Error {
    case networkUnavailable
    case unauthorized
    case rateLimited
    case serverError
    case decodingFailed
    case unknown(underlying: Error)

    var userMessage: String {
        switch self {
        case .networkUnavailable:
            return L10n.Error.Network.transport
        case .unauthorized:
            return L10n.Error.Network.unauthorized
        case .rateLimited:
            return L10n.Error.Network.rateLimited
        case .serverError:
            return L10n.Error.Network.serverUnavailable
        case .decodingFailed:
            return L10n.Error.Network.decoding
        case .unknown:
            return L10n.Error.Network.unknown
        }
    }
}

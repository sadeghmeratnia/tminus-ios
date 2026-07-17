//
//  LaunchError.swift
//  TMinus
//
//  Created by Sadegh on 22/05/2026.
//

import Foundation

enum LaunchError: Error, Equatable {
    case networkUnavailable
    case unauthorized
    case rateLimited
    case serverError
    case decodingFailed
    case unknown(underlying: ErrorSummary)
}

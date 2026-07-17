//
//  NewsError.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import Foundation

enum NewsError: Error, Sendable {
    case networkUnavailable
    case unauthorized
    case rateLimited
    case serverError
    case decodingFailed
    case unknown(underlying: any Error & Sendable)
}

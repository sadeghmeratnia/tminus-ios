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
    case decoding(any Error & Sendable)
    case unknown(underlying: any Error & Sendable)
}

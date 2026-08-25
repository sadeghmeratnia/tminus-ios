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

// MARK: - Equatable

extension NetworkError: Equatable {
    /// `.decoding`/`.unknown` box an `any Error`, which isn't generally `Equatable`, so exact
    /// payload comparison isn't possible in general. Bridging both sides to `NSError` and
    /// comparing domain+code, the same identity `ErrorSummary` itself is built from, is enough
    /// to catch the common test-authoring mistake of asserting `.decoding(...)`/`.unknown(...)`
    /// against the wrong underlying error, without requiring `any Error & Sendable` to be
    /// `Equatable`. Two distinct error *values* that happen to share a domain+code are still
    /// treated as equal here, same tradeoff `ErrorSummary`'s own `Equatable` makes.
    static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL),
             (.requestEncoding, .requestEncoding),
             (.invalidResponse, .invalidResponse):
            true
        case let (.statusCode(lhsCode), .statusCode(rhsCode)):
            lhsCode == rhsCode
        case let (.transport(lhsError), .transport(rhsError)):
            lhsError == rhsError
        case let (.decoding(lhsError), .decoding(rhsError)),
             let (.unknown(lhsError), .unknown(rhsError)):
            ErrorSummary(lhsError) == ErrorSummary(rhsError)
        default:
            false
        }
    }
}

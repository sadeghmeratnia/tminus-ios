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
    case decoding(Error)
    case unknown(underlying: Error)
}

extension NetworkError {
    var userMessage: String {
        switch self {
        case .invalidURL, .requestEncoding:
            return "We could not create the request."
        case .invalidResponse:
            return "The server returned an invalid response."
        case .statusCode(let code):
            if code == 401 || code == 403 {
                return "You are not authorised to perform this action."
            }
            if code == 429 {
                return "Too many requests. Please try again in a moment."
            }
            if code >= 500 {
                return "The server is currently unavailable. Please try again shortly."
            }
            return "Something went wrong while loading data."
        case .transport:
            return "Please check your internet connection and try again."
        case .decoding:
            return "We could not read the server response."
        case .unknown:
            return "Something unexpected happened. Please try again."
        }
    }
}

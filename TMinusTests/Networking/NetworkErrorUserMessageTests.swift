//
//  NetworkErrorUserMessageTests.swift
//  TMinus
//
//  Created by Sadegh on 30/04/2026.
//

@testable import TMinus
import Testing
import Foundation

// MARK: - NetworkErrorUserMessageTests

@Suite("NetworkError.userMessage")
enum NetworkErrorUserMessageTests {
    // MARK: - Request Errors

    @Suite("Request Errors")
    struct RequestErrors {
        @Test("invalidURL returns correct message")
        func invalidURL() {
            NetworkErrorUserMessageTests.assertMessage(
                .invalidURL,
                equals: NetworkErrorUserMessageTests.requestCreationMessage)
        }

        @Test("requestEncoding returns correct message")
        func requestEncoding() {
            NetworkErrorUserMessageTests.assertMessage(
                .requestEncoding,
                equals: NetworkErrorUserMessageTests.requestCreationMessage)
        }

        @Test("invalidURL and requestEncoding return same message")
        func invalidURLAndRequestEncodingReturnSameMessage() {
            #expect(NetworkError.invalidURL.userMessage == NetworkError.requestEncoding.userMessage)
        }
    }

    // MARK: - Response Errors

    @Suite("Response Errors")
    struct ResponseErrors {
        @Test("invalidResponse returns correct message")
        func invalidResponse() {
            NetworkErrorUserMessageTests.assertMessage(
                .invalidResponse,
                equals: NetworkErrorUserMessageTests.invalidResponseMessage)
        }
    }

    // MARK: - Status Code Errors

    @Suite("Status Code Errors")
    struct StatusCodeErrors {
        @Test("401 returns unauthorized message")
        func statusCode401() {
            NetworkErrorUserMessageTests.assertMessage(
                .statusCode(401),
                equals: NetworkErrorUserMessageTests.unauthorizedMessage)
        }

        @Test("403 returns unauthorized message")
        func statusCode403() {
            NetworkErrorUserMessageTests.assertMessage(
                .statusCode(403),
                equals: NetworkErrorUserMessageTests.unauthorizedMessage)
        }

        @Test("401 and 403 return same message")
        func unauthorizedCodesReturnSameMessage() {
            #expect(NetworkError.statusCode(401).userMessage == NetworkError.statusCode(403).userMessage)
        }

        @Test("429 returns rate limit message")
        func statusCode429() {
            NetworkErrorUserMessageTests.assertMessage(
                .statusCode(429),
                equals: NetworkErrorUserMessageTests.rateLimitMessage)
        }

        @Test("5xx returns server unavailable message", arguments: [500, 501, 502, 503, 504])
        func statusCode5xx(code: Int) {
            NetworkErrorUserMessageTests.assertMessage(
                .statusCode(code),
                equals: NetworkErrorUserMessageTests.serverUnavailableMessage)
        }

        @Test("Other status codes return generic message", arguments: [400, 404, 409, 422])
        func otherStatusCodes(code: Int) {
            NetworkErrorUserMessageTests.assertMessage(
                .statusCode(code),
                equals: NetworkErrorUserMessageTests.genericFailureMessage)
        }
    }

    // MARK: - Transport Errors

    @Suite("Transport Errors")
    struct TransportErrors {
        @Test("transport returns connection message")
        func transport() {
            NetworkErrorUserMessageTests.assertMessage(
                .transport(URLError(.notConnectedToInternet)),
                equals: NetworkErrorUserMessageTests.noConnectionMessage)
        }
    }

    // MARK: - Decoding Errors

    @Suite("Decoding Errors")
    struct DecodingErrors {
        @Test("decoding returns correct message")
        func decoding() {
            let error = DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: ""))
            NetworkErrorUserMessageTests.assertMessage(
                .decoding(error),
                equals: NetworkErrorUserMessageTests.decodingFailureMessage)
        }
    }

    // MARK: - Unknown Errors

    @Suite("Unknown Errors")
    struct UnknownErrors {
        @Test("unknown returns correct message")
        func unknown() {
            NetworkErrorUserMessageTests.assertMessage(
                .unknown(underlying: URLError(.unknown)),
                equals: NetworkErrorUserMessageTests.unknownFailureMessage)
        }
    }
}

extension NetworkErrorUserMessageTests {
    fileprivate static let requestCreationMessage = "We could not create the request."
    fileprivate static let invalidResponseMessage = "The server returned an invalid response."
    fileprivate static let unauthorizedMessage = "You are not authorised to perform this action."
    fileprivate static let rateLimitMessage = "Too many requests. Please try again in a moment."
    fileprivate static let serverUnavailableMessage = "The server is currently unavailable. Please try again shortly."
    fileprivate static let genericFailureMessage = "Something went wrong while loading data."
    fileprivate static let noConnectionMessage = "Please check your internet connection and try again."
    fileprivate static let decodingFailureMessage = "We could not read the server response."
    fileprivate static let unknownFailureMessage = "Something unexpected happened. Please try again."

    fileprivate static func assertMessage(_ error: NetworkError, equals expected: String) {
        #expect(error.userMessage == expected)
    }
}

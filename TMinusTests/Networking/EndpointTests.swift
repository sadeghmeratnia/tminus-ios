//
//  EndpointTests.swift
//  TMinusTests
//
//  Created by Sadegh on 22/04/2026.
//

import Testing
import Foundation
@testable import TMinus

@Suite("Endpoint")
struct EndpointTests {

    // MARK: - URL Construction

    @Suite("URL Construction")
    struct URLConstruction {

        @Test("Builds correct URL from base and path")
        func buildsCorrectURL() throws {
            let request = try makeRequest(
                path: "launches",
                baseURL: EndpointTests.launchLibraryBaseURL
            )
            #expect(request.url?.absoluteString == "https://ll.thespacedevs.com/2.3.0/launches")
        }

        @Test("Strips leading slash from path")
        func stripsLeadingSlash() throws {
            let request = try makeRequest(
                path: "/launches",
                baseURL: EndpointTests.launchLibraryBaseURL
            )
            #expect(request.url?.absoluteString == "https://ll.thespacedevs.com/2.3.0/launches")
        }

        @Test("Path without leading slash and path with leading slash produce same URL")
        func leadingSlashIsNormalized() throws {
            let withSlash = try makeRequest(
                path: "/launches",
                baseURL: EndpointTests.launchLibraryBaseURL
            )
            let withoutSlash = try makeRequest(
                path: "launches",
                baseURL: EndpointTests.launchLibraryBaseURL
            )

            #expect(withSlash.url == withoutSlash.url)
        }
    }

    // MARK: - HTTP Method

    @Suite("HTTP Method")
    struct HTTPMethodTests {

        @Test("Defaults to GET", arguments: [
            ("launches", "GET"),
            ("articles", "GET")
        ])
        func defaultsToGET(path: String, expectedMethod: String) throws {
            let request = try makeRequest(path: path)

            #expect(request.httpMethod == expectedMethod)
        }

        @Test("Sets correct HTTP method", arguments: [
            HTTPMethod.get,
            HTTPMethod.post,
            HTTPMethod.put
        ])
        func setsHTTPMethod(method: HTTPMethod) throws {
            let request = try makeRequest(path: "launches", method: method)

            #expect(request.httpMethod == method.rawValue)
        }
    }

    // MARK: - Query Items

    @Suite("Query Items")
    struct QueryItemTests {

        @Test("Appends query items to URL")
        func appendsQueryItems() throws {
            let request = try makeRequest(
                path: "launches",
                queryItems: [URLQueryItem(name: "limit", value: "10")]
            )
            let components = URLComponents(url: try #require(request.url), resolvingAgainstBaseURL: false)

            #expect(components?.queryItems?.contains(URLQueryItem(name: "limit", value: "10")) == true)
        }

        @Test("Appends multiple query items")
        func appendsMultipleQueryItems() throws {
            let request = try makeRequest(
                path: "launches",
                queryItems: [
                    URLQueryItem(name: "limit", value: "10"),
                    URLQueryItem(name: "offset", value: "20")
                ]
            )
            let components = URLComponents(url: try #require(request.url), resolvingAgainstBaseURL: false)

            #expect(components?.queryItems?.count == 2)
        }

        @Test("Empty query items produces no query string")
        func emptyQueryItems() throws {
            let request = try makeRequest(path: "launches", queryItems: [])

            #expect(request.url?.query == nil)
        }
    }

    // MARK: - Headers

    @Suite("Headers")
    struct HeaderTests {

        @Test("Sets custom headers on request")
        func setsHeaders() throws {
            let request = try makeRequest(
                path: "launches",
                headers: ["Authorization": "Bearer token123"]
            )

            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token123")
        }

        @Test("Sets multiple headers")
        func setsMultipleHeaders() throws {
            let request = try makeRequest(
                path: "launches",
                headers: [
                    "Authorization": "Bearer token123",
                    "Accept": "application/json"
                ]
            )

            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token123")
            #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        }

        @Test("No headers produces empty header fields")
        func noHeaders() throws {
            let request = try makeRequest(path: "launches")

            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        }
    }

    // MARK: - Timeout

    @Suite("Timeout")
    struct TimeoutTests {

        @Test("Defaults to 30 seconds")
        func defaultTimeout() throws {
            let request = try makeRequest(path: "launches")

            #expect(request.timeoutInterval == 30)
        }

        @Test("Sets custom timeout interval")
        func customTimeout() throws {
            let request = try makeRequest(path: "launches", timeoutInterval: 60)

            #expect(request.timeoutInterval == 60)
        }
    }
}

private extension EndpointTests {
    static let defaultBaseURL = URL(string: "https://example.com/")!
    static let launchLibraryBaseURL = URL(string: "https://ll.thespacedevs.com/2.3.0/")!

    static func makeRequest(
        path: String,
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:],
        timeoutInterval: TimeInterval = 30,
        baseURL: URL = defaultBaseURL
    ) throws -> URLRequest {
        try Endpoint(
            path: path,
            method: method,
            queryItems: queryItems,
            headers: headers,
            timeoutInterval: timeoutInterval
        )
        .urlRequest(baseURL: baseURL)
    }
}

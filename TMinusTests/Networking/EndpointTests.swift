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
            let endpoint = Endpoint(path: "launches")
            let baseURL = URL(string: "https://ll.thespacedevs.com/2.3.0/")!

            let request = try endpoint.urlRequest(baseURL: baseURL)

            #expect(request.url?.absoluteString == "https://ll.thespacedevs.com/2.3.0/launches")
        }

        @Test("Strips leading slash from path")
        func stripsLeadingSlash() throws {
            let endpoint = Endpoint(path: "/launches")
            let baseURL = URL(string: "https://ll.thespacedevs.com/2.3.0/")!

            let request = try endpoint.urlRequest(baseURL: baseURL)

            #expect(request.url?.absoluteString == "https://ll.thespacedevs.com/2.3.0/launches")
        }

        @Test("Path without leading slash and path with leading slash produce same URL")
        func leadingSlashIsNormalized() throws {
            let baseURL = URL(string: "https://ll.thespacedevs.com/2.3.0/")!
            let withSlash = try Endpoint(path: "/launches").urlRequest(baseURL: baseURL)
            let withoutSlash = try Endpoint(path: "launches").urlRequest(baseURL: baseURL)

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
            let endpoint = Endpoint(path: path)
            let request = try endpoint.urlRequest(baseURL: URL(string: "https://example.com/")!)

            #expect(request.httpMethod == expectedMethod)
        }

        @Test("Sets correct HTTP method", arguments: [
            HTTPMethod.get,
            HTTPMethod.post,
            HTTPMethod.put
        ])
        func setsHTTPMethod(method: HTTPMethod) throws {
            let endpoint = Endpoint(path: "launches", method: method)
            let request = try endpoint.urlRequest(baseURL: URL(string: "https://example.com/")!)

            #expect(request.httpMethod == method.rawValue)
        }
    }

    // MARK: - Query Items

    @Suite("Query Items")
    struct QueryItemTests {

        @Test("Appends query items to URL")
        func appendsQueryItems() throws {
            let endpoint = Endpoint(
                path: "launches",
                queryItems: [URLQueryItem(name: "limit", value: "10")]
            )
            let request = try endpoint.urlRequest(baseURL: URL(string: "https://example.com/")!)
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)

            #expect(components?.queryItems?.contains(URLQueryItem(name: "limit", value: "10")) == true)
        }

        @Test("Appends multiple query items")
        func appendsMultipleQueryItems() throws {
            let endpoint = Endpoint(
                path: "launches",
                queryItems: [
                    URLQueryItem(name: "limit", value: "10"),
                    URLQueryItem(name: "offset", value: "20")
                ]
            )
            let request = try endpoint.urlRequest(baseURL: URL(string: "https://example.com/")!)
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)

            #expect(components?.queryItems?.count == 2)
        }

        @Test("Empty query items produces no query string")
        func emptyQueryItems() throws {
            let endpoint = Endpoint(path: "launches", queryItems: [])
            let request = try endpoint.urlRequest(baseURL: URL(string: "https://example.com/")!)

            #expect(request.url?.query == nil)
        }
    }

    // MARK: - Headers

    @Suite("Headers")
    struct HeaderTests {

        @Test("Sets custom headers on request")
        func setsHeaders() throws {
            let endpoint = Endpoint(
                path: "launches",
                headers: ["Authorization": "Bearer token123"]
            )
            let request = try endpoint.urlRequest(baseURL: URL(string: "https://example.com/")!)

            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token123")
        }

        @Test("Sets multiple headers")
        func setsMultipleHeaders() throws {
            let endpoint = Endpoint(
                path: "launches",
                headers: [
                    "Authorization": "Bearer token123",
                    "Accept": "application/json"
                ]            )
            let request = try endpoint.urlRequest(baseURL: URL(string: "https://example.com/")!)

            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token123")
            #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        }

        @Test("No headers produces empty header fields")
        func noHeaders() throws {
            let endpoint = Endpoint(path: "launches")
            let request = try endpoint.urlRequest(baseURL: URL(string: "https://example.com/")!)

            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        }
    }

    // MARK: - Timeout

    @Suite("Timeout")
    struct TimeoutTests {

        @Test("Defaults to 30 seconds")
        func defaultTimeout() throws {
            let endpoint = Endpoint(path: "launches")
            let request = try endpoint.urlRequest(baseURL: URL(string: "https://example.com/")!)

            #expect(request.timeoutInterval == 30)
        }

        @Test("Sets custom timeout interval")
        func customTimeout() throws {
            let endpoint = Endpoint(path: "launches", timeoutInterval: 60)
            let request = try endpoint.urlRequest(baseURL: URL(string: "https://example.com/")!)

            #expect(request.timeoutInterval == 60)
        }
    }
}

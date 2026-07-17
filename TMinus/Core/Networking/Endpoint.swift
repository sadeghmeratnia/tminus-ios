//
//  Endpoint.swift
//  TMinus
//
//  Created by Sadegh on 22/04/2026.
//

import Foundation

// MARK: - HTTPMethod

enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
}

// MARK: - Endpoint

struct Endpoint: Sendable {
    let baseURL: URL
    let path: String
    let method: HTTPMethod
    let queryItems: [URLQueryItem]
    let headers: [String: String]
    let timeoutInterval: TimeInterval
    let cacheable: Bool
    let cacheTTL: TimeInterval?

    init(baseURL: URL,
         path: String,
         method: HTTPMethod = .get,
         queryItems: [URLQueryItem] = [],
         headers: [String: String] = [:],
         timeoutInterval: TimeInterval = 30,
         cacheable: Bool = true,
         cacheTTL: TimeInterval? = nil) {
        self.baseURL = baseURL
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.headers = headers
        self.timeoutInterval = timeoutInterval
        self.cacheable = cacheable
        self.cacheTTL = cacheTTL
    }

    func urlRequest() throws -> URLRequest {
        let relativePath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let endpointURL = baseURL.appending(path: relativePath)

        guard var components = URLComponents(url: endpointURL, resolvingAgainstBaseURL: false)
        else { throw NetworkError.invalidURL }

        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let finalURL = components.url else {
            throw NetworkError.requestEncoding
        }

        var request = URLRequest(url: finalURL)
        request.httpMethod = method.rawValue
        request.timeoutInterval = timeoutInterval
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        return request
    }
}

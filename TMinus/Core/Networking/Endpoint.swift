//
//  Endpoint.swift
//  TMinus
//
//  Created by Sadegh on 22/04/2026.
//

import Foundation

// MARK: - HTTPMethod

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"

    /// Whether a request using this method is safe to retry automatically after a transient
    /// failure (timeout, connection loss, 5xx). GET/PUT are idempotent by HTTP semantics,
    /// repeating them has the same effect as sending them once. POST is not: if the response to
    /// a POST is lost after the server has already applied it, blindly retrying re-executes it.
    /// `RetryPolicy` consults this before ever retrying a request.
    var isIdempotent: Bool {
        switch self {
        case .get, .put: true
        case .post: false
        }
    }
}

// MARK: - Endpoint

struct Endpoint {
    let baseURL: URL
    /// Must already be percent-encoded where it carries any dynamic/untrusted content, see
    /// `urlRequest()`'s doc comment for why, and `String.urlPathComponentEncoded` for the helper
    /// that does it. Every literal path segment in this codebase (`"launches/upcoming/"`, etc.)
    /// is plain ASCII with no reserved characters, so it's valid as-is; only a segment built from
    /// a runtime value (e.g. `LaunchesEndpoint.detail(id:)`) needs the helper applied first.
    let path: String
    let method: HTTPMethod
    let queryItems: [URLQueryItem]
    let headers: [String: String]
    let body: Data?
    let timeoutInterval: TimeInterval
    /// Whether a response to this endpoint may ever be written to `DataCache`. See `FetchPolicy`
    /// for how this composes with the caller's own cache-read choice, this and `cacheTTL` are
    /// the endpoint's half of that decision, `FetchPolicy` is the call site's half.
    let cacheable: Bool
    let cacheTTL: TimeInterval?

    init(baseURL: URL,
         path: String,
         method: HTTPMethod = .get,
         queryItems: [URLQueryItem] = [],
         headers: [String: String] = [:],
         body: Data? = nil,
         timeoutInterval: TimeInterval = 30,
         cacheable: Bool = true,
         cacheTTL: TimeInterval? = nil)
    {
        self.baseURL = baseURL
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.headers = headers
        self.body = body
        self.timeoutInterval = timeoutInterval
        self.cacheable = cacheable
        self.cacheTTL = cacheTTL
    }

    func urlRequest() throws -> URLRequest {
        let relativePath = path.hasPrefix("/") ? String(path.dropFirst()) : path

        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        else { throw NetworkError.invalidURL }

        // Deliberately not `baseURL.appending(path: relativePath)`: that API re-percent-encodes
        // its argument as though it were entirely unencoded, which double-encodes any `%` a
        // caller's own encoding pass already produced (e.g. `String.urlPathComponentEncoded`
        // turning a `/` inside a dynamic id into `%2F`, a second pass through `appending(path:)`
        // would then turn that into `%252F`, corrupting the id rather than safely escaping it).
        // Setting `percentEncodedPath` directly performs no further encoding, so `path`'s
        // contract (see its doc comment) is that it's already valid as one percent-encoded path
        //, true for both this codebase's plain-ASCII literal segments and its one dynamic
        // segment (`LaunchesEndpoint.detail`/`NewsEndpoint.detail`, both pre-encoded via
        // `urlPathComponentEncoded`).
        if relativePath.isEmpty == false {
            let basePath = components.percentEncodedPath
            // A URL with an authority component (a host) requires its path to either be empty or
            // start with `/`, `baseURL`'s own path is frequently empty (e.g. `https://example.com`,
            // with no trailing slash), not just non-empty-without-a-trailing-slash, so the
            // separator is needed whenever `basePath` doesn't already end in one, not only when
            // it's non-empty.
            let separator = basePath.hasSuffix("/") ? "" : "/"
            components.percentEncodedPath = basePath + separator + relativePath
        }
        // An empty `relativePath` means "the URL is already complete" (e.g. an absolute media URL
        // used as its own `baseURL`), `components` is left exactly as parsed from `baseURL`,
        // including whatever query string it already carried.

        // Only overwrite `components.queryItems` when the endpoint actually supplies some.
        // Unconditionally nil-ing it out here would strip any query string `baseURL` already
        // carried when `path` is empty (the "URL is already complete" case above), e.g. a
        // signed/CDN image URL's `?token=...&expires=...`, turning a valid request into one the
        // server rejects.
        if queryItems.isEmpty == false {
            components.queryItems = queryItems
        }

        guard let finalURL = components.url else {
            throw NetworkError.requestEncoding
        }

        var request = URLRequest(url: finalURL)
        request.httpMethod = method.rawValue
        request.timeoutInterval = timeoutInterval
        // The app owns its own TTL-based caching (`DataCache`); Foundation's HTTP cache sitting
        // underneath it would otherwise be a second, uncoordinated cache layer that could serve
        // a response the app-level cache already decided was stale.
        request.cachePolicy = .reloadIgnoringLocalCacheData
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        if let body {
            request.httpBody = body
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }
        return request
    }
}

// MARK: - Path component encoding

extension String {
    /// Percent-encodes this string for safe use as a single URL path component, rather than
    /// interpolated into a path template as-is (e.g. `"launches/\(id)/"`). `/` (and `..`, once
    /// escaped) can no longer be read as path separators by `URL.appending(path:)`/
    /// `URLComponents`, so a value containing one, e.g. `"../search"`, can't add or redirect
    /// path segments instead of being treated as one opaque identifier. Every id this app
    /// currently interpolates into a path (`LaunchesEndpoint.detail`, `NewsEndpoint.detail`)
    /// comes from an already-decoded, trusted server DTO, so this is defense-in-depth today,
    /// but a boundary an id could reach from an untrusted source (a deep link, user input) in the
    /// future should not have to remember to add this later.
    var urlPathComponentEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlPathComponentAllowed) ?? self
    }
}

private extension CharacterSet {
    /// `.urlPathAllowed` alone isn't enough here: it permits `/`, since it's meant for encoding
    /// a *complete* path, not one component of it.
    static let urlPathComponentAllowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))
}

//
//  URLSessionNetworkClient.swift
//  TMinus
//
//  Created by Sadegh on 22/04/2026.
//

import Foundation

// MARK: - URLSessionNetworkClient

final class URLSessionNetworkClient: NetworkClientProtocol, Sendable {
    private let session: NetworkSession
    private let makeDecoder: @Sendable () -> JSONDecoder
    private let retryPolicy: RetryPolicy
    private let logger: NetworkLogger
    private let cache: any DataCaching
    private let inFlightRequests = InFlightRequestStore()

    init(session: NetworkSession,
         decoder: JSONDecoder,
         retryPolicy: RetryPolicy,
         logger: NetworkLogger,
         cache: any DataCaching)
    {
        self.session = session
        makeDecoder = {
            let configuredDecoder = JSONDecoder()
            configuredDecoder.keyDecodingStrategy = decoder.keyDecodingStrategy
            configuredDecoder.dateDecodingStrategy = decoder.dateDecodingStrategy
            configuredDecoder.dataDecodingStrategy = decoder.dataDecodingStrategy
            configuredDecoder.nonConformingFloatDecodingStrategy = decoder.nonConformingFloatDecodingStrategy
            configuredDecoder.userInfo = decoder.userInfo
            return configuredDecoder
        }
        self.retryPolicy = retryPolicy
        self.logger = logger
        self.cache = cache
    }

    func requestData(endpoint: Endpoint, cachePolicy: FetchPolicy) async throws -> Data {
        let request = try endpoint.urlRequest()

        // Computed once and reused for both the lookup and the store below, rather than
        // recomputing the same deterministic value (URL parsing + query-item sort) twice.
        let cacheKey = cacheKey(for: request, endpoint: endpoint)

        if cachePolicy == .useCache, let cacheKey {
            if let cachedValue = await cache.cachedValue(for: cacheKey) {
                let source = String(describing: cachedValue.metadata.source)
                // Logs a redacted description, not the raw `cacheKey`, the key itself folds in
                // every header value verbatim (see `cacheKey(for:endpoint:)`) so two requests
                // differing only by header can't collide, but that's exactly why it isn't safe to
                // print as-is: nothing in this app currently sends an `Authorization` header, but
                // the moment one does, an unredacted cache key would put it straight into
                // `.public`-privacy OS logs.
                //
                // Deliberately not `cachedValue.metadata.isStale` here: that property always reads
                // the real wall clock, while `DataCache.cachedValue(for:)` itself decided
                // freshness against its own injected clock (real in production, but controllable
                // in tests), the two can only ever disagree in a test, but logging the property
                // instead of the fact this call site already establishes (this branch is only
                // reached with the default `allowingStale: false`, so a returned value is always
                // fresh *per the clock that actually gated it*) would be redundant at best and
                // misleading at worst.
                logger.log(
                    "↻ Cache hit \(redactedURLString(request.url)) headers=\(redactedHeaderDescription(endpoint.headers)) "
                        + "source=\(source) stale=false",
                    level: .debug
                )
                return cachedValue.data
            }
        }

        // `.networkOnly` never coalesces with an in-flight `.useCache` fetch for the same
        // resource, coalescing exists to stop redundant network calls, but a `.networkOnly`
        // caller has explicitly asked to bypass the cache, and silently handing it another
        // caller's response would quietly break that contract. It still writes through to the
        // cache afterward (if cacheable), same as before, so a later `.useCache` caller benefits.
        guard let cacheKey, cachePolicy == .useCache else {
            let data = try await execute(request: request)
            if let cacheKey {
                await cache.set(data, for: cacheKey, ttl: endpoint.cacheTTL, source: .network)
            }
            return data
        }

        // Coalesce concurrent `.useCache` requests for the same cacheable resource: if another
        // caller is already fetching this exact key, join its in-flight `Task` instead of firing
        // a duplicate network request that would just race it to populate the same cache entry.
        // The cache write happens *inside* the coalesced operation, run exactly once by whichever
        // caller actually created the `Task`, joiners only await its result, so there's no race
        // over which caller's `cacheTTL` wins and no redundant repeated write.
        return try await inFlightRequests.data(for: cacheKey) { [self] in
            let data = try await execute(request: request)
            await cache.set(data, for: cacheKey, ttl: endpoint.cacheTTL, source: .network)
            return data
        }
    }

    func request<T: Decodable & Sendable>(_ type: T.Type, endpoint: Endpoint, cachePolicy: FetchPolicy) async throws -> T {
        let data = try await requestData(endpoint: endpoint, cachePolicy: cachePolicy)
        do {
            return try await decode(type, from: data)
        } catch {
            logger.log("✖ Decoding failed for \(T.self): \(error)", level: .error)
            throw NetworkError.decoding(ErrorSummary(error))
        }
    }

    /// Runs off the caller's actor so JSON decoding never blocks the MainActor.
    @concurrent
    private func decode<T: Decodable & Sendable>(_ type: T.Type, from data: Data) async throws -> T {
        try makeDecoder().decode(type, from: data)
    }

    /// `deadline` is established once by the top-level caller (`nil` default) and threaded
    /// through every recursive retry unchanged, without a shared wall-clock ceiling, a request
    /// with a 30s per-attempt timeout and several retries at up to 30s backoff each could chain
    /// for minutes before ever surfacing a final error, bounded only by whether *something else*
    /// (e.g. a cancelled Task) happens to stop it first.
    private func execute(request: URLRequest, attempt: Int = 0, deadline: Date? = nil) async throws -> Data {
        try Task.checkCancellation()
        // Logged here, immediately before the one call site that actually reaches the network,
        // rather than unconditionally at the top of `requestData`, so a cache hit or a joiner
        // coalescing onto another caller's in-flight request never logs a "→" line for a network
        // call that didn't happen. Only on `attempt == 0`: retries already get their own
        // "⚠️ Retrying attempt" log below, so logging "→" again per attempt would be redundant.
        if attempt == 0 {
            logger.log(
                "→ \(request.httpMethod ?? "") \(redactedURLString(request.url)) "
                    + "headers=\(redactedHeaderDescription(request.allHTTPHeaderFields ?? [:]))",
                level: .info
            )
        }
        // `deadline` only bounds *retries*, the ceiling below only stops a subsequent attempt
        // from starting once already past it, it can't abort an attempt already in flight. An
        // `Endpoint.timeoutInterval` longer than `maxRetryWindow` would let that first attempt
        // alone exceed the ceiling this is meant to guarantee. `assert` alone isn't a real
        // guarantee, it no-ops in Release, so a misconfigured endpoint would silently blow the
        // documented ceiling in production. The request is therefore actually clamped below,
        // with the assert kept only as a loud, immediate signal in Debug that the endpoint's
        // timeout is misconfigured relative to this constant.
        assert(
            request.timeoutInterval <= Constants.maxRetryWindow,
            "Endpoint.timeoutInterval (\(request.timeoutInterval)s) exceeds Constants.maxRetryWindow "
                + "(\(Constants.maxRetryWindow)s) — a single attempt could already exceed the retry deadline."
        )
        var request = request
        if request.timeoutInterval > Constants.maxRetryWindow {
            logger.log(
                "⚠️ Endpoint.timeoutInterval (\(request.timeoutInterval)s) exceeds "
                    + "Constants.maxRetryWindow (\(Constants.maxRetryWindow)s); clamping.",
                level: .warning
            )
            request.timeoutInterval = Constants.maxRetryWindow
        }
        let deadline = deadline ?? Date().addingTimeInterval(Constants.maxRetryWindow)
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            guard (200 ... 299).contains(httpResponse.statusCode) else {
                // The body itself is logged via `sensitiveDetail:`, not folded into `message`,
                // unlike the status line, it's arbitrary server-controlled content that can echo
                // request fields or account-identifying detail, so it must stay off `.public`
                // logging (see `NetworkLogger.log(_:sensitiveDetail:level:)`).
                logger.log(
                    "← \(httpResponse.statusCode) body=",
                    sensitiveDetail: responseBodyPreview(data),
                    level: .error
                )
                return try await retryOrThrow(
                    NetworkError.statusCode(httpResponse.statusCode),
                    request: request,
                    attempt: attempt,
                    deadline: deadline,
                    retryAfter: retryAfterSeconds(from: httpResponse)
                )
            }

            logger.log("← \(httpResponse.statusCode)", level: .info)
            return data

        } catch is CancellationError {
            logger.log("ℹ️ Request cancelled", level: .info)
            throw CancellationError()

        } catch let urlError as URLError where urlError.code == .cancelled {
            // URLSession surfaces task cancellation as URLError(.cancelled), not Swift's
            // CancellationError, so it must be rethrown as the latter for callers'
            // `catch is CancellationError` to see it instead of a spurious network error.
            logger.log("ℹ️ Request cancelled", level: .info)
            throw CancellationError()

        } catch let urlError as URLError {
            return try await retryOrThrow(
                NetworkError.transport(urlError),
                request: request,
                attempt: attempt,
                deadline: deadline,
                retryAfter: nil
            )

        } catch let networkError as NetworkError {
            // Rethrown as-is to avoid the generic catch below re-wrapping an already-classified
            // NetworkError (e.g. from the recursive retry call) as `.unknown(underlying:)`.
            throw networkError

        } catch {
            logger.log("✖ Unknown error: \(error)", level: .error)
            throw NetworkError.unknown(underlying: ErrorSummary(error))
        }
    }

    private func retryOrThrow(_ error: NetworkError,
                              request: URLRequest,
                              attempt: Int,
                              deadline: Date,
                              retryAfter: TimeInterval?) async throws -> Data
    {
        let method = HTTPMethod(rawValue: request.httpMethod ?? HTTPMethod.get.rawValue) ?? .get
        guard retryPolicy.shouldRetry(error: error, attempt: attempt, method: method), Date() < deadline else {
            logger.log("✖ Non-retryable: \(error)", level: .error)
            throw error
        }
        // Clamp the sleep itself to whatever time remains before `deadline`, rather than sleeping
        // the policy's full backoff unconditionally, an unclamped sleep can, on its own, carry
        // the request past `maxRetryWindow` by up to a full backoff delay (`RetryPolicy`'s
        // `maxDelaySeconds`), since the `Date() < deadline` check just above only guards against
        // starting the sleep late, not against the sleep itself overrunning the deadline.
        let remainingBeforeSleep = deadline.timeIntervalSinceNow
        guard remainingBeforeSleep > 0 else {
            logger.log("✖ Retry deadline exceeded: \(error)", level: .error)
            throw error
        }
        let delay = min(retryPolicy.delay(for: attempt, retryAfter: retryAfter), .seconds(remainingBeforeSleep))
        logger.log("⚠️ Retrying attempt \(attempt + 1): \(error)", level: .warning)
        try await Task.sleep(for: delay)

        // Re-checked after the sleep, and the next attempt's own per-request timeout clamped to
        // whatever time remains, so a single retry cycle can't overshoot the ceiling either by
        // sleeping right up to it or by then running a full-length attempt on top of that.
        let remaining = deadline.timeIntervalSinceNow
        guard remaining > 0 else {
            logger.log("✖ Retry deadline exceeded: \(error)", level: .error)
            throw error
        }
        var nextRequest = request
        nextRequest.timeoutInterval = min(nextRequest.timeoutInterval, remaining)
        return try await execute(request: nextRequest, attempt: attempt + 1, deadline: deadline)
    }

    /// Parses the standard `Retry-After` header as a delta-seconds value (the HTTP-date form is
    /// rare for JSON APIs and deliberately not handled here, an unparsed header just falls back
    /// to the policy's own exponential backoff, which is always a safe default).
    private func retryAfterSeconds(from response: HTTPURLResponse) -> TimeInterval? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After"),
              let seconds = TimeInterval(value.trimmingCharacters(in: .whitespaces))
        else { return nil }
        return seconds
    }

    /// Bounded, best-effort text preview of a failed response's body for diagnostics, third-party
    /// APIs often put the actually-useful detail (e.g. a validation message) in the body, which
    /// `NetworkError.statusCode(Int)` alone discards. Kept out of the error type itself (rather
    /// than added as an associated value) so `NetworkError` stays trivially `Equatable`-by-case
    /// for callers/tests that only care about the status code.
    private func responseBodyPreview(_ data: Data) -> String {
        guard data.isEmpty == false else { return "<empty>" }
        guard let text = String(data: data.prefix(Constants.maxLoggedBodyBytes), encoding: .utf8) else {
            return "<\(data.count) bytes, non-UTF8>"
        }
        return data.count > Constants.maxLoggedBodyBytes ? "\(text)…" : text
    }

    /// Best-effort redaction for logging only, never used to build the actual `cacheKey` or the
    /// request itself, only what gets printed. Covers the sensitive-header and sensitive-query-
    /// parameter names a "reference architecture" app is likely to introduce (auth tokens, API
    /// keys) so adding one doesn't silently start leaking it into `.public`-privacy OS logs; it's
    /// a denylist, not a guarantee, so any endpoint sending secrets under a name not listed here
    /// still needs its own care.
    private func redactedURLString(_ url: URL?) -> String {
        guard let url, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url?.absoluteString ?? ""
        }
        components.queryItems = components.queryItems?.map { item in
            guard isSensitiveParameterName(item.name) else { return item }
            return URLQueryItem(name: item.name, value: "<redacted>")
        }
        return components.url?.absoluteString ?? url.absoluteString
    }

    private func redactedHeaderDescription(_ headers: [String: String]) -> String {
        headers
            .sorted { $0.key < $1.key }
            .map { key, value in
                let displayValue = isSensitiveParameterName(key) ? "<redacted>" : value
                return "\(key)=\(displayValue)"
            }
            .joined(separator: "&")
    }

    /// Substring match against `Constants.sensitiveParameterSubstrings`, not an exact-name
    /// lookup, an exact denylist only catches header/query-parameter names it already knows
    /// verbatim, so a real-world variant like `id_token`, `refresh_token`, `client_secret`, or
    /// `x-auth-token` would previously log unredacted the moment such a name was introduced,
    /// despite plainly being the kind of value this redaction exists for. Still a best-effort
    /// denylist, not a guarantee, see `Constants.sensitiveParameterSubstrings`'s doc comment.
    private func isSensitiveParameterName(_ name: String) -> Bool {
        let lowercased = name.lowercased()
        return Constants.sensitiveParameterSubstrings.contains { lowercased.contains($0) }
    }

    private func cacheKey(for request: URLRequest, endpoint: Endpoint) -> String? {
        guard endpoint.cacheable,
              request.httpMethod == HTTPMethod.get.rawValue,
              let url = request.url,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return nil }

        // Sort query items so the same logical request always produces the same cache key,
        // regardless of the order they happened to be constructed in.
        components.queryItems = components.queryItems?.sorted {
            $0.name == $1.name ? ($0.value ?? "") < ($1.value ?? "") : $0.name < $1.name
        }

        guard let stableURLString = components.url?.absoluteString else { return nil }

        // Fold headers into the key too: two requests to the same URL that differ only by a
        // header (e.g. `Accept-Language`, or a future per-user `Authorization`) must not share a
        // cache entry, or one caller's response could be silently served to a different context.
        let headerSuffix = endpoint.headers
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")

        return "\(HTTPMethod.get.rawValue)|\(stableURLString)|\(headerSuffix)"
    }
}

// MARK: - InFlightRequestStore

/// Coalesces concurrent requests for the same cache key into a single in-flight `Task`, so a
/// burst of callers asking for the same resource before the first one resolves triggers one
/// network call instead of a duplicate for each caller ("thundering herd").
private actor InFlightRequestStore {
    private var tasks: [String: Task<Data, Error>] = [:]

    /// Deliberately does *not* propagate the caller's own cancellation into an early return: the
    /// underlying `Task` is shared by every joiner, including ones that arrived after this call
    /// and are not cancelled, so cancelling *this* await can't cancel the shared work without
    /// also aborting those other joiners' in-flight fetch. A cancelled caller therefore still
    /// waits for the shared task to settle rather than fast-failing, the alternative (a
    /// cancellation-aware race, e.g. via a `TaskGroup`) would add meaningful complexity/latency
    /// overhead for a case (cancelling mid-coalesced-fetch) that isn't currently load-bearing
    /// anywhere in the app.
    func data(for key: String, operation: @Sendable @escaping () async throws -> Data) async throws -> Data {
        if let existing = tasks[key] {
            return try await existing.value
        }
        let task = Task<Data, Error> { try await operation() }
        tasks[key] = task
        // Removes this entry once *this* call's task settles (success or failure), so the next
        // logical request for the key starts a fresh fetch rather than replaying a stale result.
        // Concurrent joiners that arrived while this was in flight took the `existing` branch
        // above and simply await the same task's value directly, they don't run this defer.
        defer { tasks[key] = nil }
        return try await task.value
    }
}

// MARK: - Constants

private extension URLSessionNetworkClient {
    enum Constants {
        /// Wall-clock ceiling on the total time a single logical request may spend retrying,
        /// independent of `RetryPolicy`'s per-attempt backoff, caps the worst case instead of
        /// letting `maxRetries` × per-attempt timeout compound unbounded.
        static let maxRetryWindow: TimeInterval = 60
        static let maxLoggedBodyBytes = 1024
        /// Case-insensitive substrings, not exact names, matched against every header/query-
        /// parameter name before logging (see `isSensitiveParameterName`); a header/parameter
        /// name is redacted if it *contains* any of these, so `id_token`, `refresh_token`,
        /// `client_secret`, `x-auth-token`, etc. are all caught by `token`/`secret`/`auth` alone
        /// without needing their own explicit entry. Still a denylist, not a guarantee: any
        /// endpoint sending a secret under a name that matches none of these substrings needs its
        /// own care.
        static let sensitiveParameterSubstrings: Set<String> = [
            "auth", "cookie",
            "api-key", "apikey", "api_key",
            "token", "secret", "password",
        ]
    }
}

//
//  NetworkErrorClassifier.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import Foundation

// MARK: - NetworkErrorClassification

enum NetworkErrorClassification {
    case networkUnavailable
    /// A request that timed out, distinct from `.networkUnavailable` because a slow/overloaded
    /// server is a different failure than "this device has no usable network path," and the two
    /// warrant different user-facing copy.
    case timeout
    case unauthorized
    case rateLimited
    case serverError
    /// Any other 4xx status (400, 404, 422, …) not already covered by `.unauthorized`/
    /// `.rateLimited` above, a malformed request or a genuinely-missing resource. Kept distinct
    /// from `.unknown` so a real client-side request problem isn't presented to the user
    /// identically to an unclassifiable failure (e.g. a decoding bug), which would otherwise
    /// discard information this layer already has.
    case clientError(statusCode: Int)
    case decodingFailed
    case unknown(underlying: ErrorSummary)
}

// MARK: - NetworkErrorClassifier

enum NetworkErrorClassifier {
    static func classify(_ error: Error) -> NetworkErrorClassification {
        // Every current call site (`CachedFetchCoordinator`, `LaunchRepository`,
        // `NewsRepository`) already intercepts `is CancellationError` before ever reaching this
        // function, rethrowing it as-is instead of classifying it, a classification has no case
        // that means "this wasn't really a failure," so a `CancellationError` reaching here would
        // otherwise fall through to `.unknown` and surface as a spurious "Something went wrong"
        // instead of silently propagating. That guarantee currently lives only in caller
        // discipline, which a new call site or a reordered `catch` could silently break, this
        // `assert` turns a violation into an immediate, loud Debug/test failure rather than a
        // release-only, hard-to-reproduce bad error message. Still resolved to `.unknown` below
        // in Release (where `assert` no-ops) since degrading gracefully beats crashing in
        // production over what is, at that point, just a misleading message.
        assert(
            (error is CancellationError) == false,
            "NetworkErrorClassifier.classify(_:) received a CancellationError — the caller must "
                + "intercept cancellation before classification instead of relying on this to do it."
        )
        guard let networkError = error as? NetworkError else {
            return .unknown(underlying: ErrorSummary(error))
        }

        switch networkError {
        case let .transport(urlError):
            guard urlError.code != .timedOut else {
                return .timeout
            }
            guard isConnectivityLoss(urlError) else {
                // Summarize the actual `URLError`, not the outer `NetworkError`, the latter has
                // no custom NSError bridging, so wrapping it produces a generic Swift-bridged
                // domain/code instead of the real `NSURLErrorDomain` code (e.g. -1200 for a TLS
                // failure) that's actually useful for diagnosing the failure.
                return .unknown(underlying: ErrorSummary(urlError))
            }
            return .networkUnavailable
        case let .statusCode(code) where code == 401 || code == 403:
            return .unauthorized
        case let .statusCode(code) where code == 429:
            return .rateLimited
        case let .statusCode(code) where code >= 500:
            return .serverError
        case let .statusCode(code) where (400 ... 499).contains(code):
            return .clientError(statusCode: code)
        case .decoding:
            return .decodingFailed
        case let .unknown(underlying):
            // Summarize the wrapped error itself, not the outer `NetworkError.unknown` case,
            // same reasoning as `.transport` above. `NetworkError` has no custom `NSError`
            // bridging, so wrapping the case directly discards the wrapped error's real
            // domain/code (e.g. the original `NSURLErrorDomain` code) behind a generic
            // Swift-bridged one, exactly the failure mode this classifier exists to avoid.
            return .unknown(underlying: ErrorSummary(underlying))
        default:
            return .unknown(underlying: ErrorSummary(networkError))
        }
    }

    /// Only these codes actually mean "the device has no usable network path", a generic
    /// "you're offline" message for e.g. a bad TLS cert or DNS misconfiguration would hide a
    /// real bug behind what looks like a connectivity problem. `.timedOut` is handled separately
    /// by the caller before this is reached, since a timeout doesn't necessarily mean the device
    /// has no network path, it may just mean a slow or overloaded server.
    private static func isConnectivityLoss(_ urlError: URLError) -> Bool {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost,
             .dataNotAllowed, .internationalRoamingOff, .callIsActive:
            return true
        default:
            return false
        }
    }
}

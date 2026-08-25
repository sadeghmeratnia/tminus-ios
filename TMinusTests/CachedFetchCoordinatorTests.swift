//
//  CachedFetchCoordinatorTests.swift
//  TMinusTests
//

import Foundation
import Testing
@testable import TMinus

/// Exercises `CachedFetchCoordinator.fetch` directly against injected closures, both
/// `LaunchRepository`/`NewsRepository` route through this shared helper, so a regression here
/// would silently affect both features. Two branches specifically had no coverage anywhere in the
/// suite before this file: the "confident empty result" `localHasFreshDataIgnoringFilter` path,
/// and the persist-failure-is-swallowed-not-thrown path.
@Suite("CachedFetchCoordinator")
struct CachedFetchCoordinatorTests {
    private struct Item: Sendable, Equatable {
        let id: String
    }

    private struct StubError: Error, Equatable {
        let tag: String
    }

    @Test("A non-empty local cache read is returned without ever calling remote")
    func nonEmptyLocalCacheShortCircuitsRemote() async throws {
        var remoteCalled = false

        let result = try await CachedFetchCoordinator.fetch(
            fetchPolicy: .useCache,
            maxAge: 60,
            local: { _ in [Item(id: "1")] },
            wrap: { (items: [Item]) -> [Item] in items },
            remote: {
                remoteCalled = true
                return [Item(id: "remote")]
            },
            persist: { _ in },
            onLocalReadFailure: { _ in },
            onPersistFailure: { _ in }
        )

        #expect(result == [Item(id: "1")])
        #expect(remoteCalled == false)
    }

    @Test("An empty local read that is confidently fresh (filter matched nothing) returns empty without calling remote")
    func confidentEmptyResultSkipsRemote() async throws {
        var remoteCalled = false

        let result = try await CachedFetchCoordinator.fetch(
            fetchPolicy: .useCache,
            maxAge: 60,
            local: { _ in [] },
            localHasFreshDataIgnoringFilter: { _ in true },
            wrap: { (items: [Item]) -> [Item] in items },
            remote: {
                remoteCalled = true
                return [Item(id: "remote")]
            },
            persist: { _ in },
            onLocalReadFailure: { _ in },
            onPersistFailure: { _ in }
        )

        #expect(result.isEmpty)
        #expect(remoteCalled == false)
    }

    @Test("An empty local read where the unfiltered cache is not fresh falls through to remote")
    func emptyLocalWithoutConfidentFreshDataFallsThroughToRemote() async throws {
        var remoteCalled = false

        let result = try await CachedFetchCoordinator.fetch(
            fetchPolicy: .useCache,
            maxAge: 60,
            local: { _ in [] },
            localHasFreshDataIgnoringFilter: { _ in false },
            wrap: { (items: [Item]) -> [Item] in items },
            remote: {
                remoteCalled = true
                return [Item(id: "remote")]
            },
            persist: { _ in },
            onLocalReadFailure: { _ in },
            onPersistFailure: { _ in }
        )

        #expect(result == [Item(id: "remote")])
        #expect(remoteCalled)
    }

    @Test("A failing initial local read reports the failure and still falls through to remote")
    func failingLocalReadReportsAndFallsThroughToRemote() async throws {
        var reportedError: StubError?

        let result = try await CachedFetchCoordinator.fetch(
            fetchPolicy: .useCache,
            maxAge: 60,
            local: { _ in throw StubError(tag: "local-read") },
            wrap: { (items: [Item]) -> [Item] in items },
            remote: { [Item(id: "remote")] },
            persist: { _ in },
            onLocalReadFailure: { reportedError = $0 as? StubError },
            onPersistFailure: { _ in }
        )

        #expect(result == [Item(id: "remote")])
        #expect(reportedError == StubError(tag: "local-read"))
    }

    @Test("A successful result is returned even when persisting it fails, and the failure is reported")
    func persistFailureIsSwallowedButReported() async throws {
        var reportedError: StubError?

        let result = try await CachedFetchCoordinator.fetch(
            fetchPolicy: .useCache,
            maxAge: 60,
            local: { _ in [] },
            localHasFreshDataIgnoringFilter: { _ in false },
            wrap: { (items: [Item]) -> [Item] in items },
            remote: { [Item(id: "remote")] },
            persist: { _ in throw StubError(tag: "persist") },
            onLocalReadFailure: { _ in },
            onPersistFailure: { reportedError = $0 as? StubError }
        )

        #expect(result == [Item(id: "remote")])
        #expect(reportedError == StubError(tag: "persist"))
    }

    @Test("A remote failure under .useCache falls back to a stale local read instead of throwing")
    func remoteFailureFallsBackToStaleLocalRead() async throws {
        let result = try await CachedFetchCoordinator.fetch(
            fetchPolicy: .useCache,
            maxAge: 60,
            local: { maxAge in maxAge == nil ? [Item(id: "stale")] : [] },
            localHasFreshDataIgnoringFilter: { _ in false },
            wrap: { (items: [Item]) -> [Item] in items },
            remote: { throw StubError(tag: "remote") },
            persist: { _ in },
            onLocalReadFailure: { _ in },
            onPersistFailure: { _ in }
        )

        #expect(result == [Item(id: "stale")])
    }

    @Test(".networkOnly never falls back to a stale local read on remote failure")
    func networkOnlyDoesNotFallBackOnRemoteFailure() async throws {
        var staleReadAttempted = false

        await #expect(throws: NetworkFeatureError.self) {
            _ = try await CachedFetchCoordinator.fetch(
                fetchPolicy: .networkOnly,
                maxAge: 60,
                local: { _ in
                    staleReadAttempted = true
                    return [Item(id: "stale")]
                },
                wrap: { (items: [Item]) -> [Item] in items },
                remote: { throw StubError(tag: "remote") },
                persist: { _ in },
                onLocalReadFailure: { _ in },
                onPersistFailure: { _ in }
            )
        }

        #expect(staleReadAttempted == false)
    }

    @Test("Cancellation from the remote fetch propagates as CancellationError, not a mapped network error")
    func remoteCancellationPropagates() async throws {
        await #expect(throws: CancellationError.self) {
            _ = try await CachedFetchCoordinator.fetch(
                fetchPolicy: .networkOnly,
                maxAge: 60,
                local: { _ in [] },
                wrap: { (items: [Item]) -> [Item] in items },
                remote: { throw CancellationError() },
                persist: { _ in },
                onLocalReadFailure: { _ in },
                onPersistFailure: { _ in }
            )
        }
    }
}

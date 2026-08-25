//
//  LaunchLocalModelMapperTests.swift
//  TMinusTests
//
//  Created by Sadegh on 17/08/2026.
//

import Foundation
import Testing
@testable import TMinus

@Suite("LaunchLocalModelMapper")
struct LaunchLocalModelMapperTests {
    @Test("Every LaunchStatus case round-trips through the persisted model unchanged", arguments: [
        LaunchStatus.go,
        .toBeDetermined,
        .hold,
        .success,
        .failure,
        .unknown("Partial Failure"),
        .unknown(nil),
    ])
    func statusRoundTrips(status: LaunchStatus) {
        let launch = Self.makeLaunch(status: status)

        let model = LaunchLocalModelMapper.map(launch)
        let roundTripped = LaunchLocalModelMapper.map(model)

        #expect(roundTripped.status == status)
    }

    // Simulates a schema migration or corrupted row: a `statusCode` string on disk that doesn't
    // match any `PersistedStatusCode` case (e.g. left over from a renamed case, or written by a
    // future app version this one doesn't understand yet).
    @Test("An unrecognized persisted statusCode falls back to .unknown rather than crashing or defaulting silently")
    func unrecognizedPersistedStatusCodeFallsBackToUnknown() {
        let launch = Self.makeLaunch(status: .go)
        let model = LaunchLocalModelMapper.map(launch)
        model.statusCode = "some-future-status-this-app-version-does-not-know"
        model.statusLabel = "Future Status"

        let roundTripped = LaunchLocalModelMapper.map(model)

        #expect(roundTripped.status == .unknown("Future Status"))
    }

    @Test("resolvedStatusCodes matches exactly the persisted codes for success and failure")
    func resolvedStatusCodesMatchesSuccessAndFailure() {
        let successCode = LaunchLocalModelMapper.map(Self.makeLaunch(status: .success)).statusCode
        let failureCode = LaunchLocalModelMapper.map(Self.makeLaunch(status: .failure)).statusCode
        let goCode = LaunchLocalModelMapper.map(Self.makeLaunch(status: .go)).statusCode

        #expect(LaunchLocalModelMapper.resolvedStatusCodes == [successCode, failureCode])
        #expect(LaunchLocalModelMapper.resolvedStatusCodes.contains(goCode) == false)
    }

    @Test("unknownStatusCode matches the code an .unknown status actually persists as")
    func unknownStatusCodeMatchesPersistedUnknownStatus() {
        let model = LaunchLocalModelMapper.map(Self.makeLaunch(status: .unknown("Weather Delay")))

        #expect(model.statusCode == LaunchLocalModelMapper.unknownStatusCode)
    }

    @Test("update(_:from:fetchedAt:) produces the same persisted state as map(_:fetchedAt:)")
    func updateMatchesMap() {
        let launch = Self.makeLaunch(status: .hold)
        let fetchedAt = Date(timeIntervalSince1970: 1_000_000)

        let mapped = LaunchLocalModelMapper.map(launch, fetchedAt: fetchedAt)
        let updated = LaunchLocalModelMapper.map(Self.makeLaunch(status: .go))
        LaunchLocalModelMapper.update(updated, from: launch, fetchedAt: fetchedAt)

        #expect(updated.statusCode == mapped.statusCode)
        #expect(updated.statusLabel == mapped.statusLabel)
        #expect(updated.name == mapped.name)
        #expect(updated.nameLowercased == mapped.nameLowercased)
    }
}

private extension LaunchLocalModelMapperTests {
    static func makeLaunch(status: LaunchStatus) -> Launch {
        Launch(
            id: "launch-1",
            name: "Starship Flight 5",
            status: status,
            windowStart: Date(timeIntervalSince1970: 1_700_000_000),
            windowEnd: nil,
            rocket: nil,
            launchPad: nil,
            mission: nil,
            imageURL: nil,
            webcastURL: nil
        )
    }
}

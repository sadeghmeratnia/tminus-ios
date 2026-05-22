//
//  LaunchListReducerTests.swift
//  TMinusTests
//
//  Created by Sadegh on 12/05/2026.
//

@testable import TMinus
import Testing
import Foundation

@Suite("LaunchListReducer")
enum LaunchListReducerTests {
    @Test("Appear loads current mode using cache")
    static func appearLoadsCurrentMode() {
        let state: LaunchListState = .idle(mode: .upcoming)

        let result = LaunchListReducer.reduce(state: state, action: .appear)

        #expect(result.state.mode == .upcoming)
        #expect(result.state.launches.isEmpty)
        guard case let .load(mode, previousLaunches, fetchPolicy) = result.effect else {
            Issue.record("Expected load effect")
            return
        }
        #expect(mode == .upcoming)
        #expect(previousLaunches.isEmpty)
        #expect(fetchPolicy == .useCache)
    }

    @Test("Refresh keeps previous launches and reloads ignoring cache")
    static func refreshKeepsPreviousLaunches() {
        let previousLaunches = [makeLaunch(id: "1"), makeLaunch(id: "2")]
        let state: LaunchListState = .loaded(mode: .previous, launches: previousLaunches)

        let result = LaunchListReducer.reduce(state: state, action: .refresh)

        #expect(result.state.mode == .previous)
        #expect(result.state.launches == previousLaunches)
        guard case let .load(mode, launches, fetchPolicy) = result.effect else {
            Issue.record("Expected load effect")
            return
        }
        #expect(mode == .previous)
        #expect(launches == previousLaunches)
        #expect(fetchPolicy == .networkOnly)
    }

    @Test("Mode change to same mode has no effect")
    static func modeChangedToSameModeNoEffect() {
        let launches = [makeLaunch(id: "x")]
        let state: LaunchListState = .loaded(mode: .upcoming, launches: launches)

        let result = LaunchListReducer.reduce(state: state, action: .modeChanged(.upcoming))

        #expect(result.state.mode == .upcoming)
        #expect(result.state.launches == launches)
        #expect(result.effect == nil)
    }

    @Test("Load response with error keeps previous launches")
    static func loadResponseWithError() {
        let previousLaunches = [makeLaunch(id: "keep")]
        let errorMessage = "Network failed"

        let result = LaunchListReducer.reduce(
            state: .loading(mode: .upcoming, launches: previousLaunches),
            action: .loadResponse(
                mode: .upcoming,
                previousLaunches: previousLaunches,
                launches: [],
                errorMessage: errorMessage))

        #expect(result.state.mode == .upcoming)
        #expect(result.state.launches == previousLaunches)
        #expect(result.effect == nil)
    }
}

private extension LaunchListReducerTests {
    static func makeLaunch(id: String) -> Launch {
        Launch(
            id: id,
            name: "Launch \(id)",
            status: .go,
            windowStart: Date(timeIntervalSince1970: 1_000),
            windowEnd: nil,
            rocket: LaunchRocket(id: 1, name: "Falcon 9"),
            launchPad: LaunchPad(id: "10", name: "LC-39A", latitude: 0, longitude: 0, locationName: "KSC"),
            mission: nil,
            imageURL: nil,
            webcastURL: nil)
    }
}

//
//  LaunchDetailReducerTests.swift
//  TMinusTests
//
//  Created by Sadegh on 28/05/2026.
//

import Foundation
import Testing
@testable import TMinus

@Suite("LaunchDetailReducer")
enum LaunchDetailReducerTests {
    @Test("Appear starts loading and triggers fetch effect")
    static func appearStartsLoading() {
        let state = LaunchDetailState.initial(launchID: "launch-1")

        let result = LaunchDetailReducer.reduce(state: state, action: .appear)

        #expect(result.state.phase == .loading)
        #expect(result.state.launchID == "launch-1")
        #expect(result.state.loadGeneration == LoadGeneration(current: 1))
        guard case let .load(id, generation) = result.effect else {
            Issue.record("Expected load effect")
            return
        }
        #expect(id == "launch-1")
        #expect(generation == 1)
    }

    @Test("Appear is ignored after first load has started")
    static func appearIgnoredWhenNotIdle() {
        let state = LaunchDetailState(
            launchID: "launch-1",
            launch: nil,
            phase: .loading,
            relatedArticles: [],
            loadGeneration: LoadGeneration(current: 1)
        )

        let result = LaunchDetailReducer.reduce(state: state, action: .appear)

        #expect(result.state.phase == .loading)
        #expect(result.effect == nil)
    }

    @Test("Successful load response stores launch")
    static func loadResponseSuccess() {
        let launch = makeLaunch(id: "launch-1")
        let state = LaunchDetailState(launchID: "launch-1", launch: nil, phase: .loading, relatedArticles: [], loadGeneration: LoadGeneration(current: 1))

        let result = LaunchDetailReducer.reduce(
            state: state,
            action: .loadResponse(launch: launch, errorMessage: nil, generation: 1)
        )

        #expect(result.state.phase == .loaded)
        #expect(result.state.launch == launch)
        #expect(result.effect == nil)
    }

    @Test("Failed load response enters error phase")
    static func loadResponseFailure() {
        let state = LaunchDetailState(launchID: "launch-1", launch: nil, phase: .loading, relatedArticles: [], loadGeneration: LoadGeneration(current: 1))
        let errorMessage = "Network failed"

        let result = LaunchDetailReducer.reduce(
            state: state,
            action: .loadResponse(launch: nil, errorMessage: errorMessage, generation: 1)
        )

        if case let .error(message) = result.state.phase {
            #expect(message == errorMessage)
        } else {
            Issue.record("Expected error phase")
        }
        #expect(result.effect == nil)
    }

    @Test("A response from a superseded generation is dropped")
    static func staleGenerationResponseIsDropped() {
        let launch = makeLaunch(id: "launch-1")
        // Two loads have started (generation 2 is current); a response tagged for the
        // first (generation 1) arrives late and must not clobber the newer in-flight load.
        let state = LaunchDetailState(launchID: "launch-1", launch: nil, phase: .loading, relatedArticles: [], loadGeneration: LoadGeneration(current: 2))

        let result = LaunchDetailReducer.reduce(
            state: state,
            action: .loadResponse(launch: launch, errorMessage: nil, generation: 1)
        )

        #expect(result.state == state)
        #expect(result.state.launch == nil)
    }

    @Test("Retry reloads from error state")
    static func retryFromError() {
        let state = LaunchDetailState(
            launchID: "launch-1",
            launch: nil,
            phase: .error(message: "Network failed"),
            relatedArticles: [],
            loadGeneration: LoadGeneration(current: 1)
        )

        let result = LaunchDetailReducer.reduce(state: state, action: .retry)

        #expect(result.state.phase == .loading)
        #expect(result.state.loadGeneration == LoadGeneration(current: 2))
        guard case let .load(id, generation) = result.effect else {
            Issue.record("Expected load effect")
            return
        }
        #expect(id == "launch-1")
        #expect(generation == 2)
    }

    @Test("Related news response populates related articles without affecting phase")
    static func relatedNewsResponseSuccess() {
        let launch = makeLaunch(id: "launch-1")
        let state = LaunchDetailState(launchID: "launch-1", launch: launch, phase: .loaded, relatedArticles: [], loadGeneration: LoadGeneration(current: 1))
        let article = makeArticle(id: "article-1")

        let result = LaunchDetailReducer.reduce(state: state, action: .relatedNewsResponse([article]))

        #expect(result.state.relatedArticles == [article])
        #expect(result.state.phase == .loaded)
        #expect(result.effect == nil)
    }

    @Test("Empty related news response leaves the section empty without an error")
    static func relatedNewsResponseEmpty() {
        let launch = makeLaunch(id: "launch-1")
        let state = LaunchDetailState(launchID: "launch-1", launch: launch, phase: .loaded, relatedArticles: [], loadGeneration: LoadGeneration(current: 1))

        let result = LaunchDetailReducer.reduce(state: state, action: .relatedNewsResponse([]))

        #expect(result.state.relatedArticles.isEmpty)
        #expect(result.state.phase == .loaded)
    }
}

private extension LaunchDetailReducerTests {
    static func makeLaunch(id: String) -> Launch {
        Launch(
            id: id,
            name: "Launch \(id)",
            status: .go,
            windowStart: Date(timeIntervalSince1970: 1000),
            windowEnd: nil,
            rocket: LaunchRocket(id: 1, name: "Falcon 9"),
            launchPad: LaunchPad(id: "10", name: "LC-39A", latitude: 0, longitude: 0, locationName: "KSC"),
            mission: nil,
            imageURL: nil,
            webcastURL: nil
        )
    }

    static func makeArticle(id: String) -> NewsArticle {
        NewsArticle(
            id: id,
            title: "Article \(id)",
            summary: "Summary",
            url: URL(string: "https://example.com/\(id)")!,
            imageURL: nil,
            newsSite: "SpaceNews",
            publishedAt: Date(timeIntervalSince1970: 1000),
            relatedLaunchIDs: ["launch-1"]
        )
    }
}

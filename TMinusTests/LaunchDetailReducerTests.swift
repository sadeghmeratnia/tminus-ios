//
//  LaunchDetailReducerTests.swift
//  TMinusTests
//
//  Created by Sadegh on 28/05/2026.
//

@testable import TMinus
import Testing
import Foundation

@Suite("LaunchDetailReducer")
enum LaunchDetailReducerTests {
    @Test("Appear starts loading and triggers fetch effect")
    static func appearStartsLoading() {
        let state = LaunchDetailState.initial(launchID: "launch-1")

        let result = LaunchDetailReducer.reduce(state: state, action: .appear)

        #expect(result.state.phase == .loading)
        #expect(result.state.launchID == "launch-1")
        guard case let .load(id) = result.effect else {
            Issue.record("Expected load effect")
            return
        }
        #expect(id == "launch-1")
    }

    @Test("Appear is ignored after first load has started")
    static func appearIgnoredWhenNotIdle() {
        let state = LaunchDetailState(
            launchID: "launch-1",
            launch: nil,
            phase: .loading,
            relatedArticles: [])

        let result = LaunchDetailReducer.reduce(state: state, action: .appear)

        #expect(result.state.phase == .loading)
        #expect(result.effect == nil)
    }

    @Test("Successful load response stores launch")
    static func loadResponseSuccess() {
        let launch = makeLaunch(id: "launch-1")
        let state = LaunchDetailState(launchID: "launch-1", launch: nil, phase: .loading, relatedArticles: [])

        let result = LaunchDetailReducer.reduce(
            state: state,
            action: .loadResponse(launch: launch, errorMessage: nil))

        #expect(result.state.phase == .loaded)
        #expect(result.state.launch == launch)
        #expect(result.effect == nil)
    }

    @Test("Failed load response enters error phase")
    static func loadResponseFailure() {
        let state = LaunchDetailState(launchID: "launch-1", launch: nil, phase: .loading, relatedArticles: [])
        let errorMessage = "Network failed"

        let result = LaunchDetailReducer.reduce(
            state: state,
            action: .loadResponse(launch: nil, errorMessage: errorMessage))

        if case let .error(message) = result.state.phase {
            #expect(message == errorMessage)
        } else {
            Issue.record("Expected error phase")
        }
        #expect(result.effect == nil)
    }

    @Test("Retry reloads from error state")
    static func retryFromError() {
        let state = LaunchDetailState(
            launchID: "launch-1",
            launch: nil,
            phase: .error(message: "Network failed"),
            relatedArticles: [])

        let result = LaunchDetailReducer.reduce(state: state, action: .retry)

        #expect(result.state.phase == .loading)
        guard case let .load(id) = result.effect else {
            Issue.record("Expected load effect")
            return
        }
        #expect(id == "launch-1")
    }

    @Test("Related news response populates related articles without affecting phase")
    static func relatedNewsResponseSuccess() {
        let launch = makeLaunch(id: "launch-1")
        let state = LaunchDetailState(launchID: "launch-1", launch: launch, phase: .loaded, relatedArticles: [])
        let article = makeArticle(id: "article-1")

        let result = LaunchDetailReducer.reduce(state: state, action: .relatedNewsResponse([article]))

        #expect(result.state.relatedArticles == [article])
        #expect(result.state.phase == .loaded)
        #expect(result.effect == nil)
    }

    @Test("Empty related news response leaves the section empty without an error")
    static func relatedNewsResponseEmpty() {
        let launch = makeLaunch(id: "launch-1")
        let state = LaunchDetailState(launchID: "launch-1", launch: launch, phase: .loaded, relatedArticles: [])

        let result = LaunchDetailReducer.reduce(state: state, action: .relatedNewsResponse([]))

        #expect(result.state.relatedArticles.isEmpty)
        #expect(result.state.phase == .loaded)
    }
}

extension LaunchDetailReducerTests {
    fileprivate static func makeLaunch(id: String) -> Launch {
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
            webcastURL: nil)
    }

    fileprivate static func makeArticle(id: String) -> NewsArticle {
        NewsArticle(
            id: id,
            title: "Article \(id)",
            summary: "Summary",
            url: URL(string: "https://example.com/\(id)")!,
            imageURL: nil,
            newsSite: "SpaceNews",
            publishedAt: Date(timeIntervalSince1970: 1000),
            relatedLaunchIDs: ["launch-1"])
    }
}

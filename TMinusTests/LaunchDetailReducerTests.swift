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
        guard case let .load(id, fetchPolicy, kind, generation) = result.effect else {
            Issue.record("Expected load effect")
            return
        }
        #expect(id == "launch-1")
        #expect(fetchPolicy == .useCache)
        #expect(kind == .initial)
        #expect(generation == 1)
    }

    @Test("Appear is ignored after first load has started")
    static func appearIgnoredWhenNotIdle() {
        let state = makeState(launch: nil, phase: .loading, generation: 1)

        let result = LaunchDetailReducer.reduce(state: state, action: .appear)

        #expect(result.state.phase == .loading)
        #expect(result.effect == nil)
    }

    @Test("Successful load response stores launch")
    static func loadResponseSuccess() {
        let launch = makeLaunch(id: "launch-1")
        let state = makeState(launch: nil, phase: .loading, generation: 1)

        let result = LaunchDetailReducer.reduce(
            state: state,
            action: .loadResponse(.success(launch), kind: .initial, generation: 1)
        )

        #expect(result.state.phase == .loaded)
        #expect(result.state.launch == launch)
        #expect(result.effect == nil)
    }

    @Test("Failed initial load response enters error phase")
    static func loadResponseFailure() {
        let state = makeState(launch: nil, phase: .loading, generation: 1)
        let errorMessage = "Network failed"

        let result = LaunchDetailReducer.reduce(
            state: state,
            action: .loadResponse(.failure(errorMessage), kind: .initial, generation: 1)
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
        let state = makeState(launch: nil, phase: .loading, generation: 2)

        let result = LaunchDetailReducer.reduce(
            state: state,
            action: .loadResponse(.success(launch), kind: .initial, generation: 1)
        )

        #expect(result.state == state)
        #expect(result.state.launch == nil)
    }

    @Test("Retry reloads from error state")
    static func retryFromError() {
        let state = makeState(launch: nil, phase: .error(message: "Network failed"), generation: 1)

        let result = LaunchDetailReducer.reduce(state: state, action: .retry)

        #expect(result.state.phase == .loading)
        #expect(result.state.loadGeneration == LoadGeneration(current: 2))
        guard case let .load(id, fetchPolicy, kind, generation) = result.effect else {
            Issue.record("Expected load effect")
            return
        }
        #expect(id == "launch-1")
        #expect(fetchPolicy == .useCache)
        #expect(kind == .initial)
        #expect(generation == 2)
    }

    @Test("Retry is ignored outside the error phase")
    static func retryIgnoredWhenNotInErrorPhase() {
        let state = makeState(launch: makeLaunch(id: "launch-1"), phase: .loaded, generation: 1)

        let result = LaunchDetailReducer.reduce(state: state, action: .retry)

        #expect(result.state == state)
        #expect(result.effect == nil)
    }

    @Test("Refresh keeps the launch on screen and requests a network-only load")
    static func refreshStartsNetworkOnlyLoad() {
        let launch = makeLaunch(id: "launch-1")
        let state = makeState(launch: launch, phase: .loaded, generation: 1)

        let result = LaunchDetailReducer.reduce(state: state, action: .refresh)

        #expect(result.state.phase == .loaded)
        #expect(result.state.launch == launch)
        #expect(result.state.loadGeneration == LoadGeneration(current: 2))
        guard case let .load(id, fetchPolicy, kind, generation) = result.effect else {
            Issue.record("Expected load effect")
            return
        }
        #expect(id == "launch-1")
        #expect(fetchPolicy == .networkOnly)
        #expect(kind == .refresh)
        #expect(generation == 2)
    }

    @Test("Refresh is ignored outside the loaded phase")
    static func refreshIgnoredWhenNotLoaded() {
        let state = makeState(launch: nil, phase: .loading, generation: 1)

        let result = LaunchDetailReducer.reduce(state: state, action: .refresh)

        #expect(result.state == state)
        #expect(result.effect == nil)
    }

    @Test("A failed refresh response keeps the launch and sets a refresh error instead of the error phase")
    static func refreshFailureKeepsLaunch() {
        let launch = makeLaunch(id: "launch-1")
        let state = makeState(launch: launch, phase: .loaded, generation: 1)

        let result = LaunchDetailReducer.reduce(
            state: state,
            action: .loadResponse(.failure("Network failed"), kind: .refresh, generation: 1)
        )

        #expect(result.state.phase == .loaded)
        #expect(result.state.launch == launch)
        #expect(result.state.refreshError == "Network failed")
    }

    @Test("A successful refresh response replaces the launch and clears any refresh error")
    static func refreshSuccessReplacesLaunchAndClearsError() {
        let staleLaunch = makeLaunch(id: "launch-1")
        var state = makeState(launch: staleLaunch, phase: .loaded, generation: 1)
        state = LaunchDetailReducer.reduce(
            state: state,
            action: .loadResponse(.failure("Network failed"), kind: .refresh, generation: 1)
        ).state
        #expect(state.refreshError != nil)

        let (refreshedState, generation) = state.startingRefresh()
        let freshLaunch = makeLaunch(id: "launch-1")
        let result = LaunchDetailReducer.reduce(
            state: refreshedState,
            action: .loadResponse(.success(freshLaunch), kind: .refresh, generation: generation)
        )

        #expect(result.state.phase == .loaded)
        #expect(result.state.launch == freshLaunch)
        #expect(result.state.refreshError == nil)
    }

    @Test("Related news response populates related articles without affecting phase")
    static func relatedNewsResponseSuccess() {
        let launch = makeLaunch(id: "launch-1")
        let state = makeState(launch: launch, phase: .loaded, generation: 1, relatedNewsGeneration: 1)
        let article = makeArticle(id: "article-1")

        let result = LaunchDetailReducer.reduce(state: state, action: .relatedNewsResponse([article], generation: 1))

        #expect(result.state.relatedArticles == [article])
        #expect(result.state.relatedNewsHasLoaded == true)
        #expect(result.state.phase == .loaded)
        #expect(result.effect == nil)
    }

    @Test("Starting a related-news load advances its generation and produces a load effect tagged with it")
    static func startRelatedNewsLoadAdvancesGeneration() {
        let launch = makeLaunch(id: "launch-1")
        let state = makeState(launch: launch, phase: .loaded, generation: 1, relatedNewsGeneration: 3)

        let result = LaunchDetailReducer.reduce(state: state, action: .startRelatedNewsLoad(fetchPolicy: .networkOnly))

        guard case let .loadRelatedNews(launchID, fetchPolicy, generation) = result.effect else {
            Issue.record("Expected a .loadRelatedNews effect")
            return
        }
        #expect(launchID == "launch-1")
        #expect(fetchPolicy == .networkOnly)
        #expect(generation == 4)
        #expect(result.state.relatedNewsGeneration == LoadGeneration(current: 4))
    }

    @Test("Empty related news response leaves the section empty without an error")
    static func relatedNewsResponseEmpty() {
        let launch = makeLaunch(id: "launch-1")
        let state = makeState(launch: launch, phase: .loaded, generation: 1, relatedNewsGeneration: 1)

        let result = LaunchDetailReducer.reduce(state: state, action: .relatedNewsResponse([], generation: 1))

        #expect(result.state.relatedArticles.isEmpty)
        #expect(result.state.phase == .loaded)
    }

    @Test("A related news response from a superseded generation is dropped")
    static func relatedNewsResponseFromStaleGenerationIsDropped() {
        let launch = makeLaunch(id: "launch-1")
        let state = makeState(launch: launch, phase: .loaded, generation: 1, relatedNewsGeneration: 2)
        let article = makeArticle(id: "article-1")

        // Generation 1 is stale, generation 2 is the current related-news load.
        let result = LaunchDetailReducer.reduce(state: state, action: .relatedNewsResponse([article], generation: 1))

        #expect(result.state.relatedArticles.isEmpty)
    }

    @Test("Cancelling an in-flight main load reverts to idle so a future appear can restart it")
    static func cancellingMainLoadRevertsToIdle() {
        let state = makeState(launch: nil, phase: .loading, generation: 1)

        let result = LaunchDetailReducer.reduce(state: state, action: .cancelled)

        #expect(result.state.phase == .idle)
        #expect(result.effect == nil)
    }

    // A main-load task that doesn't observe cancellation in time can still resolve after
    // `cancelInFlightWork()` already reverted `phase` to `.idle`. Without `.cancelled` also
    // bumping `loadGeneration`, that late response would pass `applyingLoadResponse`'s guard and
    // resurrect stale state.
    @Test("Cancelling invalidates the load generation, so a late response is dropped")
    static func cancellingInvalidatesGenerationForLateResponse() {
        let (loadingState, generation) = makeState(launch: nil, phase: .idle, generation: 0).startingLoad()

        let cancelledState = LaunchDetailReducer.reduce(state: loadingState, action: .cancelled).state
        #expect(cancelledState.phase == .idle)

        let lateResponseResult = LaunchDetailReducer.reduce(
            state: cancelledState,
            action: .loadResponse(.success(makeLaunch(id: "late")), kind: .initial, generation: generation)
        )

        #expect(lateResponseResult.state == cancelledState)
    }

    @Test("Cancelling is a no-op outside the loading phase, including mid-refresh")
    static func cancellingIsANoOpOutsideLoadingPhase() {
        let launch = makeLaunch(id: "launch-1")

        let idleState = makeState(launch: nil, phase: .idle, generation: 0)
        #expect(LaunchDetailReducer.reduce(state: idleState, action: .cancelled).state == idleState)

        // `.refresh` never moves `phase` away from `.loaded`, a refresh cancelled mid-flight
        // needs no phase change at all.
        let refreshingState = makeState(launch: launch, phase: .loaded, generation: 1)
        #expect(LaunchDetailReducer.reduce(state: refreshingState, action: .cancelled).state == refreshingState)

        let errorState = makeState(launch: nil, phase: .error(message: "failed"), generation: 0)
        #expect(LaunchDetailReducer.reduce(state: errorState, action: .cancelled).state == errorState)
    }
}

private extension LaunchDetailReducerTests {
    static func makeState(launch: Launch?,
                          phase: DetailPhase,
                          generation: Int,
                          relatedNewsGeneration: Int = 0) -> LaunchDetailState
    {
        LaunchDetailState(
            launchID: "launch-1",
            launch: launch,
            phase: phase,
            relatedArticles: [],
            loadGeneration: LoadGeneration(current: generation),
            relatedNewsGeneration: LoadGeneration(current: relatedNewsGeneration),
            relatedNewsHasLoaded: false,
            refreshError: nil
        )
    }

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

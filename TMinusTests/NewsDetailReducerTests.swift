//
//  NewsDetailReducerTests.swift
//  TMinusTests
//
//  Created by Sadegh on 09/07/2026.
//

import Foundation
import Testing
@testable import TMinus

@Suite("NewsDetailReducer")
enum NewsDetailReducerTests {
    @Test("Appear starts loading and triggers fetch effect")
    static func appearStartsLoading() {
        let state = NewsDetailState.initial(articleID: "article-1")

        let result = NewsDetailReducer.reduce(state: state, action: .appear)

        #expect(result.state.phase == .loading)
        #expect(result.state.articleID == "article-1")
        #expect(result.state.loadGeneration == LoadGeneration(current: 1))
        guard case let .load(id, fetchPolicy, kind, generation) = result.effect else {
            Issue.record("Expected load effect")
            return
        }
        #expect(id == "article-1")
        #expect(fetchPolicy == .useCache)
        #expect(kind == .initial)
        #expect(generation == 1)
    }

    @Test("Appear is ignored after first load has started")
    static func appearIgnoredWhenNotIdle() {
        let state = makeState(article: nil, phase: .loading, generation: 1)

        let result = NewsDetailReducer.reduce(state: state, action: .appear)

        #expect(result.state.phase == .loading)
        #expect(result.effect == nil)
    }

    @Test("Successful load response stores article")
    static func loadResponseSuccess() {
        let article = makeArticle(id: "article-1")
        let state = makeState(article: nil, phase: .loading, generation: 1)

        let result = NewsDetailReducer.reduce(
            state: state,
            action: .loadResponse(.success(article), kind: .initial, generation: 1)
        )

        #expect(result.state.phase == .loaded)
        #expect(result.state.article == article)
        #expect(result.effect == nil)
    }

    @Test("Failed initial load response enters error phase")
    static func loadResponseFailure() {
        let state = makeState(article: nil, phase: .loading, generation: 1)
        let errorMessage = "Network failed"

        let result = NewsDetailReducer.reduce(
            state: state,
            action: .loadResponse(.failure(errorMessage), kind: .initial, generation: 1)
        )

        if case let .error(message) = result.state.phase {
            #expect(message == errorMessage)
        } else {
            Issue.record("Expected error phase")
        }
    }

    @Test("A response from a superseded generation is dropped")
    static func staleGenerationResponseIsDropped() {
        let article = makeArticle(id: "article-1")
        // Two loads have started (generation 2 is current); a response tagged for the
        // first (generation 1) arrives late and must not clobber the newer in-flight load.
        let state = makeState(article: nil, phase: .loading, generation: 2)

        let result = NewsDetailReducer.reduce(
            state: state,
            action: .loadResponse(.success(article), kind: .initial, generation: 1)
        )

        #expect(result.state == state)
        #expect(result.state.article == nil)
    }

    @Test("Retry reloads from error state")
    static func retryFromError() {
        let state = makeState(article: nil, phase: .error(message: "Network failed"), generation: 1)

        let result = NewsDetailReducer.reduce(state: state, action: .retry)

        #expect(result.state.phase == .loading)
        #expect(result.state.loadGeneration == LoadGeneration(current: 2))
        guard case let .load(id, fetchPolicy, kind, generation) = result.effect else {
            Issue.record("Expected load effect")
            return
        }
        #expect(id == "article-1")
        #expect(fetchPolicy == .useCache)
        #expect(kind == .initial)
        #expect(generation == 2)
    }

    @Test("Retry is ignored outside the error phase")
    static func retryIgnoredWhenNotInErrorPhase() {
        let state = makeState(article: makeArticle(id: "article-1"), phase: .loaded, generation: 1)

        let result = NewsDetailReducer.reduce(state: state, action: .retry)

        #expect(result.state == state)
        #expect(result.effect == nil)
    }

    @Test("Refresh keeps the article on screen and requests a network-only load")
    static func refreshStartsNetworkOnlyLoad() {
        let article = makeArticle(id: "article-1")
        let state = makeState(article: article, phase: .loaded, generation: 1)

        let result = NewsDetailReducer.reduce(state: state, action: .refresh)

        #expect(result.state.phase == .loaded)
        #expect(result.state.article == article)
        #expect(result.state.loadGeneration == LoadGeneration(current: 2))
        guard case let .load(id, fetchPolicy, kind, generation) = result.effect else {
            Issue.record("Expected load effect")
            return
        }
        #expect(id == "article-1")
        #expect(fetchPolicy == .networkOnly)
        #expect(kind == .refresh)
        #expect(generation == 2)
    }

    @Test("Refresh is ignored outside the loaded phase")
    static func refreshIgnoredWhenNotLoaded() {
        let state = makeState(article: nil, phase: .loading, generation: 1)

        let result = NewsDetailReducer.reduce(state: state, action: .refresh)

        #expect(result.state == state)
        #expect(result.effect == nil)
    }

    @Test("A failed refresh response keeps the article and sets a refresh error instead of the error phase")
    static func refreshFailureKeepsArticle() {
        let article = makeArticle(id: "article-1")
        let state = makeState(article: article, phase: .loaded, generation: 1)

        let result = NewsDetailReducer.reduce(
            state: state,
            action: .loadResponse(.failure("Network failed"), kind: .refresh, generation: 1)
        )

        #expect(result.state.phase == .loaded)
        #expect(result.state.article == article)
        #expect(result.state.refreshError == "Network failed")
    }

    @Test("A successful refresh response replaces the article and clears any refresh error")
    static func refreshSuccessReplacesArticleAndClearsError() {
        let staleArticle = makeArticle(id: "article-1")
        var state = makeState(article: staleArticle, phase: .loaded, generation: 1)
        state = NewsDetailReducer.reduce(
            state: state,
            action: .loadResponse(.failure("Network failed"), kind: .refresh, generation: 1)
        ).state
        #expect(state.refreshError != nil)

        let (refreshedState, generation) = state.startingRefresh()
        let freshArticle = makeArticle(id: "article-1")
        let result = NewsDetailReducer.reduce(
            state: refreshedState,
            action: .loadResponse(.success(freshArticle), kind: .refresh, generation: generation)
        )

        #expect(result.state.phase == .loaded)
        #expect(result.state.article == freshArticle)
        #expect(result.state.refreshError == nil)
    }

    @Test("Cancelling an in-flight main load reverts to idle so a future appear can restart it")
    static func cancellingMainLoadRevertsToIdle() {
        let state = makeState(article: nil, phase: .loading, generation: 1)

        let result = NewsDetailReducer.reduce(state: state, action: .cancelled)

        #expect(result.state.phase == .idle)
        #expect(result.effect == nil)
    }

    // See `LaunchDetailReducerTests`'s equivalent, a late response from a task that didn't
    // observe cancellation in time must be rejected by the generation guard, not resurrect state.
    @Test("Cancelling invalidates the load generation, so a late response is dropped")
    static func cancellingInvalidatesGenerationForLateResponse() {
        let (loadingState, generation) = makeState(article: nil, phase: .idle, generation: 0).startingLoad()

        let cancelledState = NewsDetailReducer.reduce(state: loadingState, action: .cancelled).state
        #expect(cancelledState.phase == .idle)

        let lateResponseResult = NewsDetailReducer.reduce(
            state: cancelledState,
            action: .loadResponse(.success(makeArticle(id: "late")), kind: .initial, generation: generation)
        )

        #expect(lateResponseResult.state == cancelledState)
    }

    @Test("Cancelling is a no-op outside the loading phase, including mid-refresh")
    static func cancellingIsANoOpOutsideLoadingPhase() {
        let article = makeArticle(id: "article-1")

        let idleState = makeState(article: nil, phase: .idle, generation: 0)
        #expect(NewsDetailReducer.reduce(state: idleState, action: .cancelled).state == idleState)

        // `.refresh` never moves `phase` away from `.loaded`, a refresh cancelled mid-flight
        // needs no phase change at all.
        let refreshingState = makeState(article: article, phase: .loaded, generation: 1)
        #expect(NewsDetailReducer.reduce(state: refreshingState, action: .cancelled).state == refreshingState)

        let errorState = makeState(article: nil, phase: .error(message: "failed"), generation: 0)
        #expect(NewsDetailReducer.reduce(state: errorState, action: .cancelled).state == errorState)
    }
}

private extension NewsDetailReducerTests {
    static func makeState(article: NewsArticle?, phase: DetailPhase, generation: Int) -> NewsDetailState {
        NewsDetailState(
            articleID: "article-1",
            article: article,
            phase: phase,
            loadGeneration: LoadGeneration(current: generation),
            refreshError: nil
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
            relatedLaunchIDs: []
        )
    }
}

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
        guard case let .load(id, generation) = result.effect else {
            Issue.record("Expected load effect")
            return
        }
        #expect(id == "article-1")
        #expect(generation == 1)
    }

    @Test("Appear is ignored after first load has started")
    static func appearIgnoredWhenNotIdle() {
        let state = NewsDetailState(articleID: "article-1", article: nil, phase: .loading, loadGeneration: LoadGeneration(current: 1))

        let result = NewsDetailReducer.reduce(state: state, action: .appear)

        #expect(result.state.phase == .loading)
        #expect(result.effect == nil)
    }

    @Test("Successful load response stores article")
    static func loadResponseSuccess() {
        let article = makeArticle(id: "article-1")
        let state = NewsDetailState(articleID: "article-1", article: nil, phase: .loading, loadGeneration: LoadGeneration(current: 1))

        let result = NewsDetailReducer.reduce(
            state: state,
            action: .loadResponse(.success(article), generation: 1)
        )

        #expect(result.state.phase == .loaded)
        #expect(result.state.article == article)
        #expect(result.effect == nil)
    }

    @Test("Failed load response enters error phase")
    static func loadResponseFailure() {
        let state = NewsDetailState(articleID: "article-1", article: nil, phase: .loading, loadGeneration: LoadGeneration(current: 1))
        let errorMessage = "Network failed"

        let result = NewsDetailReducer.reduce(
            state: state,
            action: .loadResponse(.failure(errorMessage), generation: 1)
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
        let state = NewsDetailState(articleID: "article-1", article: nil, phase: .loading, loadGeneration: LoadGeneration(current: 2))

        let result = NewsDetailReducer.reduce(
            state: state,
            action: .loadResponse(.success(article), generation: 1)
        )

        #expect(result.state == state)
        #expect(result.state.article == nil)
    }

    @Test("Retry reloads from error state")
    static func retryFromError() {
        let state = NewsDetailState(
            articleID: "article-1",
            article: nil,
            phase: .error(message: "Network failed"),
            loadGeneration: LoadGeneration(current: 1)
        )

        let result = NewsDetailReducer.reduce(state: state, action: .retry)

        #expect(result.state.phase == .loading)
        #expect(result.state.loadGeneration == LoadGeneration(current: 2))
        guard case let .load(id, generation) = result.effect else {
            Issue.record("Expected load effect")
            return
        }
        #expect(id == "article-1")
        #expect(generation == 2)
    }
}

private extension NewsDetailReducerTests {
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

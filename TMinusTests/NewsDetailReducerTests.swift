//
//  NewsDetailReducerTests.swift
//  TMinusTests
//
//  Created by Sadegh on 09/07/2026.
//

@testable import TMinus
import Testing
import Foundation

@Suite("NewsDetailReducer")
enum NewsDetailReducerTests {
    @Test("Appear starts loading and triggers fetch effect")
    static func appearStartsLoading() {
        let state = NewsDetailState.initial(articleID: "article-1")

        let result = NewsDetailReducer.reduce(state: state, action: .appear)

        #expect(result.state.phase == .loading)
        #expect(result.state.articleID == "article-1")
        guard case let .load(id) = result.effect else {
            Issue.record("Expected load effect")
            return
        }
        #expect(id == "article-1")
    }

    @Test("Appear is ignored after first load has started")
    static func appearIgnoredWhenNotIdle() {
        let state = NewsDetailState(articleID: "article-1", article: nil, phase: .loading)

        let result = NewsDetailReducer.reduce(state: state, action: .appear)

        #expect(result.state.phase == .loading)
        #expect(result.effect == nil)
    }

    @Test("Successful load response stores article")
    static func loadResponseSuccess() {
        let article = makeArticle(id: "article-1")
        let state = NewsDetailState(articleID: "article-1", article: nil, phase: .loading)

        let result = NewsDetailReducer.reduce(
            state: state,
            action: .loadResponse(article: article, errorMessage: nil))

        #expect(result.state.phase == .loaded)
        #expect(result.state.article == article)
        #expect(result.effect == nil)
    }

    @Test("Failed load response enters error phase")
    static func loadResponseFailure() {
        let state = NewsDetailState(articleID: "article-1", article: nil, phase: .loading)
        let errorMessage = "Network failed"

        let result = NewsDetailReducer.reduce(
            state: state,
            action: .loadResponse(article: nil, errorMessage: errorMessage))

        if case let .error(message) = result.state.phase {
            #expect(message == errorMessage)
        } else {
            Issue.record("Expected error phase")
        }
    }

    @Test("Retry reloads from error state")
    static func retryFromError() {
        let state = NewsDetailState(articleID: "article-1", article: nil, phase: .error(message: "Network failed"))

        let result = NewsDetailReducer.reduce(state: state, action: .retry)

        #expect(result.state.phase == .loading)
        guard case let .load(id) = result.effect else {
            Issue.record("Expected load effect")
            return
        }
        #expect(id == "article-1")
    }
}

extension NewsDetailReducerTests {
    fileprivate static func makeArticle(id: String) -> NewsArticle {
        NewsArticle(
            id: id,
            title: "Article \(id)",
            summary: "Summary",
            url: URL(string: "https://example.com/\(id)")!,
            imageURL: nil,
            newsSite: "SpaceNews",
            publishedAt: Date(timeIntervalSince1970: 1000),
            relatedLaunchIDs: [])
    }
}

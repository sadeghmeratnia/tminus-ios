//
//  NewsListReducerTests.swift
//  TMinusTests
//
//  Created by Sadegh on 09/07/2026.
//

@testable import TMinus
import Testing
import Foundation

@Suite("NewsListReducer")
enum NewsListReducerTests {
    @Test("Appear loads using cache with the current search text")
    static func appearLoadsCurrentSearch() {
        let state = NewsListState(articles: [], searchText: "starship", pagination: .initial, phase: .idle)

        let result = NewsListReducer.reduce(state: state, action: .appear)

        #expect(result.state.phase == .loading(.initial))
        guard case let .load(searchText, page, previousArticles, fetchPolicy, kind) = result.effect else {
            Issue.record("Expected load effect")
            return
        }
        #expect(searchText == "starship")
        #expect(page == 1)
        #expect(previousArticles.isEmpty)
        #expect(fetchPolicy == .useCache)
        #expect(kind == .fresh)
    }

    @Test("searchTextChanged updates text without loading")
    static func searchTextChangedUpdatesTextOnly() {
        let state = NewsListState(articles: [makeArticle(id: "1")], searchText: "", pagination: .initial, phase: .loaded)

        let result = NewsListReducer.reduce(state: state, action: .searchTextChanged("moon"))

        #expect(result.state.searchText == "moon")
        #expect(result.state.articles.count == 1)
        #expect(result.state.phase == .loaded)
        #expect(result.effect == nil)
    }

    @Test("search starts a fresh load for the debounced text")
    static func searchStartsFreshLoad() {
        let state = NewsListState(articles: [makeArticle(id: "1")], searchText: "moon", pagination: .initial, phase: .loaded)

        let result = NewsListReducer.reduce(state: state, action: .search("moon"))

        #expect(result.state.articles.isEmpty)
        #expect(result.state.phase == .loading(.initial))
        guard case let .load(searchText, page, previousArticles, fetchPolicy, kind) = result.effect else {
            Issue.record("Expected load effect")
            return
        }
        #expect(searchText == "moon")
        #expect(page == 1)
        #expect(previousArticles.isEmpty)
        #expect(fetchPolicy == .useCache)
        #expect(kind == .fresh)
    }

    @Test("A response for a superseded search is dropped")
    static func staleSearchResponseIsDropped() {
        let state = NewsListState(articles: [], searchText: "moon", pagination: .initial, phase: .loading(.initial))

        let result = NewsListReducer.reduce(
            state: state,
            action: .loadResponse(
                searchText: "mars",
                previousArticles: [],
                page: PagedResult(items: [makeArticle(id: "stale")], currentPage: 1),
                kind: .fresh,
                errorMessage: nil))

        #expect(result.state.articles.isEmpty)
        #expect(result.state == state)
    }

    @Test("A response matching the current search is applied")
    static func matchingSearchResponseIsApplied() {
        let state = NewsListState(articles: [], searchText: "moon", pagination: .initial, phase: .loading(.initial))

        let result = NewsListReducer.reduce(
            state: state,
            action: .loadResponse(
                searchText: "moon",
                previousArticles: [],
                page: PagedResult(items: [makeArticle(id: "1")], currentPage: 1),
                kind: .fresh,
                errorMessage: nil))

        #expect(result.state.articles.map(\.id) == ["1"])
        #expect(result.state.phase == .loaded)
    }

    @Test("Load more requests next page with network-only policy")
    static func loadMoreRequestsNextPage() {
        let articles = [makeArticle(id: "1")]
        let pagination = ListPagination(currentPage: 1, nextPage: 2, previousPage: nil, totalCount: 100, loadMoreError: nil)
        let state = NewsListState(articles: articles, searchText: "", pagination: pagination, phase: .loaded)

        let result = NewsListReducer.reduce(state: state, action: .loadMore)

        guard case let .load(searchText, page, previousArticles, fetchPolicy, kind) = result.effect else {
            Issue.record("Expected load-more effect")
            return
        }
        #expect(searchText == "")
        #expect(page == 2)
        #expect(previousArticles == articles)
        #expect(fetchPolicy == .networkOnly)
        #expect(kind == .loadMore)
        #expect(result.state.phase == .loading(.loadMore))
    }

    @Test("Load more is blocked while a load-more error is present")
    static func loadMoreBlockedByError() {
        let articles = [makeArticle(id: "1")]
        let pagination = ListPagination(currentPage: 1, nextPage: 2, previousPage: nil, totalCount: 100, loadMoreError: "failed")
        let state = NewsListState(articles: articles, searchText: "", pagination: pagination, phase: .loaded)

        let result = NewsListReducer.reduce(state: state, action: .loadMore)

        #expect(result.effect == nil)
    }

    @Test("Retry load more clears error and triggers load")
    static func retryLoadMoreClearsErrorAndLoads() {
        let articles = [makeArticle(id: "1")]
        let pagination = ListPagination(currentPage: 1, nextPage: 2, previousPage: nil, totalCount: 100, loadMoreError: "failed")
        let state = NewsListState(articles: articles, searchText: "", pagination: pagination, phase: .loaded)

        let result = NewsListReducer.reduce(state: state, action: .retryLoadMore)

        guard case let .load(_, page, previousArticles, fetchPolicy, kind) = result.effect else {
            Issue.record("Expected load effect from retry")
            return
        }
        #expect(page == 2)
        #expect(previousArticles == articles)
        #expect(fetchPolicy == .networkOnly)
        #expect(kind == .loadMore)
        #expect(result.state.pagination.loadMoreError == nil)
    }
}

extension NewsListReducerTests {
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

//
//  ListLoadGenerationsTests.swift
//  TMinusTests
//
//  Created by Sadegh on 23/07/2026.
//

import Testing
@testable import TMinus

@Suite("ListLoadGenerations")
struct ListLoadGenerationsTests {
    @Test("A freshly advanced fresh generation matches its own value")
    func freshGenerationMatchesItsOwnValue() {
        let generations = ListLoadGenerations()
        let (next, value) = generations.advancing(for: .fresh)

        #expect(next.matches(value, for: .fresh))
    }

    @Test("A freshly advanced load-more generation matches its own value")
    func loadMoreGenerationMatchesItsOwnValue() {
        let generations = ListLoadGenerations()
        let (next, value) = generations.advancing(for: .loadMore)

        #expect(next.matches(value, for: .loadMore))
    }

    @Test("Starting a second fresh load rejects the first fresh load's stale response")
    func secondFreshLoadRejectsFirstFreshResponse() {
        let generations = ListLoadGenerations()
        let (afterFirst, firstValue) = generations.advancing(for: .fresh)
        let (afterSecond, secondValue) = afterFirst.advancing(for: .fresh)

        #expect(afterSecond.matches(firstValue, for: .fresh) == false)
        #expect(afterSecond.matches(secondValue, for: .fresh))
    }

    @Test("A fresh load invalidates an in-flight load-more, mirroring that it cancels it")
    func freshLoadInvalidatesInFlightLoadMore() {
        let generations = ListLoadGenerations()
        let (afterLoadMore, loadMoreValue) = generations.advancing(for: .loadMore)
        let (afterFresh, _) = afterLoadMore.advancing(for: .fresh)

        #expect(afterFresh.matches(loadMoreValue, for: .loadMore) == false)
    }

    @Test("A load-more load does not invalidate an in-flight fresh load")
    func loadMoreDoesNotInvalidateInFlightFresh() {
        let generations = ListLoadGenerations()
        let (afterFresh, freshValue) = generations.advancing(for: .fresh)
        let (afterLoadMore, _) = afterFresh.advancing(for: .loadMore)

        #expect(afterLoadMore.matches(freshValue, for: .fresh))
    }

    @Test("Starting a second load-more rejects the first load-more's stale response")
    func secondLoadMoreRejectsFirstLoadMoreResponse() {
        let generations = ListLoadGenerations()
        let (afterFirst, firstValue) = generations.advancing(for: .loadMore)
        let (afterSecond, secondValue) = afterFirst.advancing(for: .loadMore)

        #expect(afterSecond.matches(firstValue, for: .loadMore) == false)
        #expect(afterSecond.matches(secondValue, for: .loadMore))
    }
}

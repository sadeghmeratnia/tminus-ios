//
//  ListContentPhaseTests.swift
//  TMinusTests
//
//  Created by Sadegh on 11/07/2026.
//

@testable import TMinus
import Testing
import Foundation

@Suite("ListContentPhase")
enum ListContentPhaseTests {
    @Test("Initial load with no items is loading, with no banner")
    static func initialLoadIsLoading() {
        let result = ListContentPhase<Int>.resolve(phase: .loading(.initial), items: [])
        #expect(result.phase == .loading)
        #expect(result.refreshErrorMessage == nil)
    }

    @Test("Error with no items surfaces the error as a full-screen phase, with no banner")
    static func errorWithNoItemsIsError() {
        let result = ListContentPhase<Int>.resolve(phase: .error(message: "failed"), items: [])
        #expect(result.phase == .error(message: "failed"))
        #expect(result.refreshErrorMessage == nil)
    }

    @Test("Idle, loaded, refresh, or load-more with no items is empty, with no banner")
    static func noItemsWithoutErrorIsEmpty() {
        for phase in [ListPhase.idle, .loaded, .loading(.refresh), .loading(.loadMore)] {
            let result = ListContentPhase<Int>.resolve(phase: phase, items: [])
            #expect(result.phase == .empty)
            #expect(result.refreshErrorMessage == nil)
        }
    }

    @Test("Any non-error phase with items present is content, with no banner")
    static func itemsWinOverNonErrorPhase() {
        let items = [1, 2, 3]
        for phase in [ListPhase.idle, .loading(.initial), .loading(.refresh), .loading(.loadMore), .loaded] {
            let result = ListContentPhase.resolve(phase: phase, items: items)
            #expect(result.phase == .content(items))
            #expect(result.refreshErrorMessage == nil)
        }
    }

    @Test("A failed refresh with stale items keeps showing them, with a banner message")
    static func errorWithItemsSurfacesBanner() {
        let items = [1, 2, 3]

        let result = ListContentPhase.resolve(phase: .error(message: "refresh failed"), items: items)

        #expect(result.phase == .content(items))
        #expect(result.refreshErrorMessage == "refresh failed")
    }
}

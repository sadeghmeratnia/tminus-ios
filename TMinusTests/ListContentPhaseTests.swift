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
    @Test("Initial load with no items is loading")
    static func initialLoadIsLoading() {
        let result = ListContentPhase<Int>.derive(phase: .loading(.initial), items: [])
        #expect(result == .loading)
    }

    @Test("Error with no items surfaces the error message")
    static func errorWithNoItemsIsError() {
        let result = ListContentPhase<Int>.derive(phase: .error(message: "failed"), items: [])
        #expect(result == .error(message: "failed"))
    }

    @Test("Idle, loaded, refresh, or load-more with no items is empty", arguments: [
        ListPhase.idle,
        .loaded,
        .loading(.refresh),
        .loading(.loadMore),
    ])
    static func noItemsWithoutErrorIsEmpty(phase: ListPhase) {
        let result = ListContentPhase<Int>.derive(phase: phase, items: [])
        #expect(result == .empty)
    }

    @Test("Any phase with items present is content, including error and initial loading")
    static func itemsAlwaysWinOverPhase() {
        let items = [1, 2, 3]
        for phase in [ListPhase.idle, .loading(.initial), .loading(.refresh), .loading(.loadMore), .loaded, .error(message: "failed")] {
            #expect(ListContentPhase.derive(phase: phase, items: items) == .content(items))
        }
    }
}

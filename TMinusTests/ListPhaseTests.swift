//
//  ListPhaseTests.swift
//  TMinusTests
//
//  Created by Sadegh on 14/07/2026.
//

import Testing
@testable import TMinus

@Suite("ListPhase")
enum ListPhaseTests {
    @Test("isLoadingMore is true only for the loadMore loading kind")
    static func isLoadingMoreOnlyForLoadMore() {
        #expect(ListPhase.loading(.loadMore).isLoadingMore)
        #expect(ListPhase.loading(.initial).isLoadingMore == false)
        #expect(ListPhase.loading(.refresh).isLoadingMore == false)
        #expect(ListPhase.idle.isLoadingMore == false)
        #expect(ListPhase.loaded.isLoadingMore == false)
        #expect(ListPhase.error(message: "failed").isLoadingMore == false)
    }
}

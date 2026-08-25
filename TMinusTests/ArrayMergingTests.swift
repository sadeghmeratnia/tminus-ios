//
//  ArrayMergingTests.swift
//  TMinusTests
//

import Foundation
import Testing
@testable import TMinus

@Suite("Array+Merging")
struct ArrayMergingTests {
    private struct Item: Identifiable, Equatable {
        let id: String
        let value: String
    }

    @Test("New items from incoming are appended in their relative order")
    func appendsNewItemsInOrder() {
        let existing = [Item(id: "1", value: "a")]
        let incoming = [Item(id: "2", value: "b"), Item(id: "3", value: "c")]

        let merged = existing.merging(incoming)

        #expect(merged.map(\.id) == ["1", "2", "3"])
    }

    @Test("Existing items keep their original position but are refreshed with incoming's fields")
    func refreshesExistingItemsInPlace() {
        let existing = [Item(id: "1", value: "old"), Item(id: "2", value: "unchanged")]
        let incoming = [Item(id: "1", value: "new")]

        let merged = existing.merging(incoming)

        #expect(merged.map(\.id) == ["1", "2"])
        #expect(merged[0].value == "new")
        #expect(merged[1].value == "unchanged")
    }

    @Test("A mix of refreshed existing items and newly appended items preserves both orderings")
    func handlesMixOfRefreshAndAppend() {
        let existing = [Item(id: "1", value: "old-1"), Item(id: "2", value: "old-2")]
        let incoming = [Item(id: "2", value: "new-2"), Item(id: "3", value: "new-3")]

        let merged = existing.merging(incoming)

        #expect(merged.map(\.id) == ["1", "2", "3"])
        #expect(merged.map(\.value) == ["old-1", "new-2", "new-3"])
    }

    @Test("Merging with an empty incoming array returns the existing array unchanged")
    func emptyIncomingLeavesExistingUnchanged() {
        let existing = [Item(id: "1", value: "a"), Item(id: "2", value: "b")]

        let merged = existing.merging([])

        #expect(merged == existing)
    }

    @Test("Merging into an empty existing array returns incoming's items in order")
    func emptyExistingReturnsIncomingInOrder() {
        let incoming = [Item(id: "1", value: "a"), Item(id: "2", value: "b")]

        let merged = [Item]().merging(incoming)

        #expect(merged == incoming)
    }

    @Test("Duplicate IDs within incoming itself keep only the later occurrence")
    func duplicateIDsWithinIncomingKeepLatestOccurrence() {
        let incoming = [Item(id: "1", value: "first"), Item(id: "1", value: "second")]

        let merged = [Item]().merging(incoming)

        #expect(merged.map(\.id) == ["1"])
        #expect(merged[0].value == "second")
    }
}

//
//  LossyDecodableArrayTests.swift
//  TMinusTests
//
//  Created by Sadegh on 23/07/2026.
//

import Foundation
import Testing
@testable import TMinus

@Suite("LossyDecodableArray")
enum LossyDecodableArrayTests {
    private struct Item: Decodable, Equatable {
        let id: Int
        let name: String
    }

    @Test("Keeps all elements when every one decodes successfully")
    static func keepsAllValidElements() throws {
        let json = """
        [{ "id": 1, "name": "a" }, { "id": 2, "name": "b" }]
        """
        let decoded = try decode([Item].self, json: json)
        #expect(decoded == [Item(id: 1, name: "a"), Item(id: 2, name: "b")])
    }

    @Test("Skips malformed elements without failing the whole array")
    static func skipsMalformedElements() throws {
        let json = """
        [{ "id": 1, "name": "a" }, { "id": "not-a-number", "name": "b" }, { "id": 3, "name": "c" }]
        """
        let decoded = try decode([Item].self, json: json)
        #expect(decoded == [Item(id: 1, name: "a"), Item(id: 3, name: "c")])
    }

    @Test("Decodes to an empty array when every element is malformed")
    static func allMalformedYieldsEmptyArray() throws {
        let json = """
        [{ "id": "x" }, { "id": "y" }]
        """
        let decoded = try decode([Item].self, json: json)
        #expect(decoded.isEmpty)
    }

    @Test("Decodes an empty array as empty")
    static func emptyArrayDecodesEmpty() throws {
        let decoded = try decode([Item].self, json: "[]")
        #expect(decoded.isEmpty)
    }
}

private extension LossyDecodableArrayTests {
    private static func decode(_: [Item].Type, json: String) throws -> [Item] {
        try JSONDecoder().decode(LossyDecodableArray<Item>.self, from: Data(json.utf8)).elements
    }
}

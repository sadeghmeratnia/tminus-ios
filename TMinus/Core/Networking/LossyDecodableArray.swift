//
//  LossyDecodableArray.swift
//  TMinus
//
//  Created by Sadegh on 23/07/2026.
//

import Foundation

// MARK: - LossyDecodableArray

/// Decodes a JSON array while skipping individual elements that fail to decode, instead of
/// failing the whole array, so one malformed record from a third-party API (e.g. a launch
/// missing a required field) doesn't blank out an entire otherwise-valid page of results.
struct LossyDecodableArray<Element: Decodable>: Decodable {
    let elements: [Element]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var elements: [Element] = []
        while container.isAtEnd == false {
            if let element = try container.decode(ElementWrapper<Element>.self).element {
                elements.append(element)
            }
        }
        self.elements = elements
    }
}

// MARK: - ElementWrapper

/// Wraps a single element's decode in `try?` so a failing element still advances the unkeyed
/// container's cursor, decoding the element directly and catching the error at the call site
/// would leave the cursor stuck on the same failed element, looping forever.
private struct ElementWrapper<Element: Decodable>: Decodable {
    let element: Element?

    init(from decoder: Decoder) throws {
        element = try? Element(from: decoder)
    }
}

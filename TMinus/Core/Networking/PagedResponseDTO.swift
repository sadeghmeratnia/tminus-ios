//
//  PagedResponseDTO.swift
//  TMinus
//
//  Created by Sadegh on 16/08/2026.
//

import Foundation

// MARK: - PagedResponseDTO

/// Generic decoding for the paginated response envelope both this app's APIs (Launch Library 2
/// and Spaceflight News) share: `count`/`next`/`previous`/`results`. Extracted from what were
/// two structurally-identical, independently-hand-written types (`LaunchesResponseDTO` and
/// `NewsResponseDTO`) so the pagination-envelope decoding logic, in particular, that one
/// malformed item must not fail the whole page, only exists in one place instead of two that
/// could silently drift apart.
struct PagedResponseDTO<Item: Decodable>: Decodable, Sendable where Item: Sendable {
    let count: Int?
    let next: String?
    let previous: String?
    let results: [Item]

    init(count: Int?, next: String?, previous: String?, results: [Item]) {
        self.count = count
        self.next = next
        self.previous = previous
        self.results = results
    }

    private enum CodingKeys: String, CodingKey {
        case count, next, previous, results
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        count = try container.decodeIfPresent(Int.self, forKey: .count)
        next = try container.decodeIfPresent(String.self, forKey: .next)
        previous = try container.decodeIfPresent(String.self, forKey: .previous)
        // One malformed item must not fail the whole page, see `LossyDecodableArray`.
        results = try container.decode(LossyDecodableArray<Item>.self, forKey: .results).elements
    }
}

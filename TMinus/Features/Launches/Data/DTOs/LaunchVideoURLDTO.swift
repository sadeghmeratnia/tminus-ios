//
//  LaunchVideoURLDTO.swift
//  TMinus
//
//  Created by Sadegh on 07/05/2026.
//

import Foundation

struct LaunchVideoURLDTO: Decodable {
    let url: URL?
    let priority: Int?

    private enum CodingKeys: String, CodingKey {
        case url
        case priority
    }

    /// `url` is decoded as a `String` and repaired via `LenientURLDecoding`, not synthesized
    /// straight to `URL`, a strict `URL`-typed `Decodable` throws on a string `URL(string:)`
    /// rejects outright (e.g. an unescaped space), and that throw would propagate out of this
    /// initializer entirely. Since entries here are only ever decoded through
    /// `LossyDecodableArray` (see `LaunchDTO.decodeVideoURLs`), an unrepaired throw doesn't fail
    /// the whole launch, it just silently drops this one video entry, which can quietly demote
    /// `LaunchDTOMapper.mapWebcastURL`'s priority-based pick to a worse (or absent) link even
    /// though the URL was perfectly repairable, the same way `imageURL` already is.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        url = LenientURLDecoding.url(from: try container.decodeIfPresent(String.self, forKey: .url))
        priority = try container.decodeIfPresent(Int.self, forKey: .priority)
    }
}

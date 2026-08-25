//
//  LaunchDTO.swift
//  TMinus
//
//  Created by Sadegh on 06/05/2026.
//

import Foundation

// MARK: - LaunchesResponseDTO

/// See `PagedResponseDTO`, the pagination envelope itself (including the "one malformed launch
/// must not fail the whole page" behavior) lives there; this is just the `LaunchDTO`-specialized
/// name callers use.
typealias LaunchesResponseDTO = PagedResponseDTO<LaunchDTO>

// MARK: - LaunchDTO

struct LaunchDTO: Decodable {
    let id: String
    let name: String
    let status: LaunchStatusDTO?
    /// Deliberately non-optional and undefended, unlike `imageURL`/`videoURLs` below: this is a
    /// countdown app, so a launch with no window-start date isn't a degraded-but-displayable
    /// launch, it's not a launch this app can show at all. `LossyDecodableArray` (see
    /// `LaunchesResponseDTO`) already keeps one such malformed row from failing an entire *list*
    /// page, that's the right place to be lossy, since the list still renders fine minus one
    /// entry. `fetchLaunchDetail` decodes a single `LaunchDTO` with no such wrapper, so the same
    /// malformed field surfaces as a decode error there instead, correct, not an oversight: the
    /// user explicitly navigated to this one launch, and a detail screen silently missing its
    /// core countdown data would be worse than the existing error state.
    let windowStart: Date
    let windowEnd: Date?
    let imageURL: String?
    let videoURLs: [LaunchVideoURLDTO]?
    let rocket: LaunchRocketDTO?
    let pad: LaunchPadDTO?
    let mission: LaunchMissionDTO?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        status = try container.decodeIfPresent(LaunchStatusDTO.self, forKey: .status)
        windowStart = try container.decode(Date.self, forKey: .windowStart)
        windowEnd = try container.decodeIfPresent(Date.self, forKey: .windowEnd)
        imageURL = try Self.decodeImageURL(from: container)
        videoURLs = try Self.decodeVideoURLs(from: container)
        rocket = try container.decodeIfPresent(LaunchRocketDTO.self, forKey: .rocket)
        pad = try container.decodeIfPresent(LaunchPadDTO.self, forKey: .pad)
        mission = try container.decodeIfPresent(LaunchMissionDTO.self, forKey: .mission)
    }

    /// `imageURL` is fully optional everywhere downstream (`LaunchDTOMapper.mapImageURL` already
    /// treats an empty/invalid string as absent), so a missing or malformed `thumbnail_url` must
    /// only leave the image absent, not throw and, via the outer `LossyDecodableArray`, drop the
    /// entire otherwise-valid launch from the page. Every step here is `try?`, not just the
    /// nested-container lookup, for that reason.
    private static func decodeImageURL(from container: KeyedDecodingContainer<CodingKeys>) throws -> String? {
        guard container.contains(.image), try !container.decodeNil(forKey: .image) else {
            return nil
        }

        guard let imageContainer = try? container.nestedContainer(keyedBy: ImageCodingKeys.self, forKey: .image) else {
            return nil
        }

        return try? imageContainer.decode(String.self, forKey: .thumbnailUrl)
    }

    /// One malformed video-URL entry (e.g. a non-URL `url` string) must not fail decoding of the
    /// whole launch, mirrors `results`' use of `LossyDecodableArray` at the response level, just
    /// applied to this nested, optional array instead. The outer `decode` call itself is wrapped
    /// in `try?`, not just each element: if `vid_urls` is ever present but not actually an array
    /// (a string, an object, anything else a flaky third-party field could send), decoding the
    /// container itself throws before `LossyDecodableArray` ever gets a chance to be lossy about
    /// individual elements, that failure must degrade to "no video URLs," not fail this launch.
    private static func decodeVideoURLs(from container: KeyedDecodingContainer<CodingKeys>) throws -> [LaunchVideoURLDTO]? {
        guard container.contains(.videoURLs), try !container.decodeNil(forKey: .videoURLs) else {
            return nil
        }
        return try? container.decode(LossyDecodableArray<LaunchVideoURLDTO>.self, forKey: .videoURLs).elements
    }
}

// MARK: - CodingKeys

extension LaunchDTO {
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case status
        case windowStart
        case windowEnd
        case image
        // The decoder applies `.convertFromSnakeCase` globally, which turns the LL2 API's
        // "vid_urls" into "vidUrls" before key matching, the raw value here must be that
        // post-conversion form, not the original snake_case JSON key.
        case videoURLs = "vidUrls"
        case rocket
        case pad
        case mission
    }

    private enum ImageCodingKeys: String, CodingKey {
        case thumbnailUrl
    }
}

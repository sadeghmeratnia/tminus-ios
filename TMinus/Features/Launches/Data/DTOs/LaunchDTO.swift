//
//  LaunchDTO.swift
//  TMinus
//
//  Created by Sadegh on 06/05/2026.
//

import Foundation

// MARK: - LaunchesResponseDTO

struct LaunchesResponseDTO: Decodable {
    let count: Int?
    let next: String?
    let previous: String?
    let results: [LaunchDTO]
}

// MARK: - LaunchDTO

struct LaunchDTO: Decodable {
    let id: String
    let name: String
    let status: LaunchStatusDTO?
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
        videoURLs = try container.decodeIfPresent([LaunchVideoURLDTO].self, forKey: .videoURLs)
        rocket = try container.decodeIfPresent(LaunchRocketDTO.self, forKey: .rocket)
        pad = try container.decodeIfPresent(LaunchPadDTO.self, forKey: .pad)
        mission = try container.decodeIfPresent(LaunchMissionDTO.self, forKey: .mission)
    }

    private static func decodeImageURL(from container: KeyedDecodingContainer<CodingKeys>) throws -> String? {
        guard container.contains(.image), try !container.decodeNil(forKey: .image) else {
            return nil
        }

        guard let imageContainer = try? container.nestedContainer(keyedBy: ImageCodingKeys.self, forKey: .image) else {
            return nil
        }

        return try imageContainer.decode(String.self, forKey: .thumbnailUrl)
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
        // "vid_urls" into "vidUrls" before key matching — the raw value here must be that
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

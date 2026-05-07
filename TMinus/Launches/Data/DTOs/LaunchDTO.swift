//
//  LaunchDTO.swift
//  TMinus
//
//  Created by Sadegh on 06/05/2026.
//

import Foundation

// MARK: - LaunchesResponseDTO

struct LaunchesResponseDTO: Decodable {
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
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.status = try container.decodeIfPresent(LaunchStatusDTO.self, forKey: .status)
        self.windowStart = try container.decode(Date.self, forKey: .windowStart)
        self.windowEnd = try container.decodeIfPresent(Date.self, forKey: .windowEnd)
        self.imageURL = try Self.decodeImageURL(from: container)
        self.videoURLs = try container.decodeIfPresent([LaunchVideoURLDTO].self, forKey: .videoURLs)
        self.rocket = try container.decodeIfPresent(LaunchRocketDTO.self, forKey: .rocket)
        self.pad = try container.decodeIfPresent(LaunchPadDTO.self, forKey: .pad)
        self.mission = try container.decodeIfPresent(LaunchMissionDTO.self, forKey: .mission)
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
        case videoURLs = "vidURLs"
        case rocket
        case pad
        case mission
    }

    private enum ImageCodingKeys: String, CodingKey {
        case thumbnailUrl
    }
}

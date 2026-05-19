//
//  LaunchDTOMapperTests.swift
//  TMinusTests
//
//  Created by Codex on 12/05/2026.
//

@testable import TMinus
import Foundation
import Testing

@Suite("LaunchDTOMapper")
enum LaunchDTOMapperTests {
    @Test("Maps known status abbreviations to domain status")
    static func mapsKnownStatus() throws {
        let dto = try decodeLaunchDTO(json: """
        {
          "id": "launch-1",
          "name": "Mission A",
          "status": { "name": "Go for launch", "abbrev": "Go" },
          "window_start": "2026-05-12T10:00:00Z",
          "window_end": null,
          "image": null,
          "vidURLs": [],
          "rocket": null,
          "pad": null,
          "mission": null
        }
        """)

        let mapped = LaunchDTOMapper.map(dto)

        #expect(mapped.status == .go)
    }

    @Test("Maps unknown status to unknown with source label")
    static func mapsUnknownStatus() throws {
        let dto = try decodeLaunchDTO(json: """
        {
          "id": "launch-2",
          "name": "Mission B",
          "status": { "name": "Weather Delay", "abbrev": "WX" },
          "window_start": "2026-05-12T10:00:00Z",
          "window_end": null,
          "image": null,
          "vidURLs": [],
          "rocket": null,
          "pad": null,
          "mission": null
        }
        """)

        let mapped = LaunchDTOMapper.map(dto)

        #expect(mapped.status == .unknown("Weather Delay"))
    }

    @Test("Sanitizes image URL by trimming and escaping spaces")
    static func sanitizesImageURL() throws {
        let dto = try decodeLaunchDTO(json: """
        {
          "id": "launch-3",
          "name": "Mission C",
          "status": null,
          "window_start": "2026-05-12T10:00:00Z",
          "window_end": null,
          "image": { "thumbnail_url": "  https://img.example.com/my image.png  " },
          "vidURLs": [],
          "rocket": null,
          "pad": null,
          "mission": null
        }
        """)

        let mapped = LaunchDTOMapper.map(dto)

        #expect(mapped.imageURL?.absoluteString == "https://img.example.com/my%20image.png")
    }

    @Test("Selects webcast URL with smallest priority")
    static func selectsLowestVideoPriority() throws {
        let dto = try decodeLaunchDTO(json: """
        {
          "id": "launch-4",
          "name": "Mission D",
          "status": null,
          "window_start": "2026-05-12T10:00:00Z",
          "window_end": null,
          "image": null,
          "vidURLs": [
            { "url": "https://youtube.com/watch?v=late", "priority": 3 },
            { "url": "https://youtube.com/watch?v=best", "priority": 1 },
            { "url": "https://youtube.com/watch?v=middle", "priority": 2 }
          ],
          "rocket": null,
          "pad": null,
          "mission": null
        }
        """)

        let mapped = LaunchDTOMapper.map(dto)

        #expect(mapped.webcastURL?.absoluteString == "https://youtube.com/watch?v=best")
    }

    @Test("Applies fallback values when rocket pad and mission are missing")
    static func appliesFallbackValues() throws {
        let dto = try decodeLaunchDTO(json: """
        {
          "id": "launch-5",
          "name": "Mission E",
          "status": null,
          "window_start": "2026-05-12T10:00:00Z",
          "window_end": null,
          "image": null,
          "vidURLs": [],
          "rocket": null,
          "pad": null,
          "mission": null
        }
        """)

        let mapped = LaunchDTOMapper.map(dto)

        #expect(mapped.rocket == LaunchRocket(id: 0, name: "Unknown Rocket"))
        #expect(mapped.launchPad == LaunchPad(id: "-1", name: "Unknown Launch Pad", latitude: 0, longitude: 0, locationName: nil))
        #expect(mapped.mission == nil)
    }
}

private extension LaunchDTOMapperTests {
    static func decodeLaunchDTO(json: String) throws -> LaunchDTO {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(LaunchDTO.self, from: Data(json.utf8))
    }
}

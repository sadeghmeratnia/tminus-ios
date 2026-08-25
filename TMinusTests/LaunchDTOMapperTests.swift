//
//  LaunchDTOMapperTests.swift
//  TMinusTests
//
//  Created by Sadegh on 12/05/2026.
//

import Foundation
import Testing
@testable import TMinus

// MARK: - LaunchDTOMapperTests

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
          "vid_urls": [],
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
          "vid_urls": [],
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
          "vid_urls": [],
          "rocket": null,
          "pad": null,
          "mission": null
        }
        """)

        let mapped = LaunchDTOMapper.map(dto)

        #expect(mapped.imageURL?.absoluteString == "https://img.example.com/my%20image.png")
    }

    @Test("Handles an image URL with a stray, non-hex '%' without producing a mis-encoded or nil URL")
    static func handlesInvalidPercentEscapeInImageURL() throws {
        // "%of" isn't a valid percent-escape (not followed by two hex digits), `mapImageURL`'s
        // first attempt is a direct `URL(string:)` parse, and Foundation's URL parser treats a
        // stray '%' like this as literal text rather than failing outright, so this exercises
        // that first branch rather than the percent-encoding fallback. The one thing this asserts
        // is that the raw '%' survives as part of a resolvable URL, never a nil (which would
        // silently drop an otherwise-usable image) and never a doubled escape.
        let dto = try decodeLaunchDTO(json: """
        {
          "id": "launch-3b",
          "name": "Mission C2",
          "status": null,
          "window_start": "2026-05-12T10:00:00Z",
          "window_end": null,
          "image": { "thumbnail_url": "https://img.example.com/50%off.png" },
          "vid_urls": [],
          "rocket": null,
          "pad": null,
          "mission": null
        }
        """)

        let mapped = LaunchDTOMapper.map(dto)

        let imageURL = try #require(mapped.imageURL)
        #expect(imageURL.host == "img.example.com")
        #expect(imageURL.absoluteString.contains("%25off") || imageURL.absoluteString.contains("%off"))
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
          "vid_urls": [
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

    @Test("Skips a top-priority entry with no url in favor of a lower-priority one that has one")
    static func skipsTopPriorityEntryMissingURL() throws {
        let dto = try decodeLaunchDTO(json: """
        {
          "id": "launch-4b",
          "name": "Mission D2",
          "status": null,
          "window_start": "2026-05-12T10:00:00Z",
          "window_end": null,
          "image": null,
          "vid_urls": [
            { "url": null, "priority": 1 },
            { "url": "https://youtube.com/watch?v=fallback", "priority": 2 }
          ],
          "rocket": null,
          "pad": null,
          "mission": null
        }
        """)

        let mapped = LaunchDTOMapper.map(dto)

        #expect(mapped.webcastURL?.absoluteString == "https://youtube.com/watch?v=fallback")
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
          "vid_urls": [],
          "rocket": null,
          "pad": null,
          "mission": null
        }
        """)

        let mapped = LaunchDTOMapper.map(dto)

        #expect(mapped.rocket == nil)
        #expect(mapped.launchPad == nil)
        #expect(mapped.mission == nil)
    }

    @Test("Keeps rocket with fallback name when only the name is missing")
    static func appliesFallbackNameForRocket() throws {
        let dto = try decodeLaunchDTO(json: """
        {
          "id": "launch-6",
          "name": "Mission F",
          "status": null,
          "window_start": "2026-05-12T10:00:00Z",
          "window_end": null,
          "image": null,
          "vid_urls": [],
          "rocket": { "configuration": { "id": 7, "name": null } },
          "pad": null,
          "mission": null
        }
        """)

        let mapped = LaunchDTOMapper.map(dto)

        #expect(mapped.rocket?.id == 7)
        #expect(mapped.rocket?.name == L10n.Common.unknown)
    }

    @Test("Keeps pad with a fallback id when only the id is missing, rather than dropping it")
    static func appliesFallbackIDForPad() throws {
        let dto = try decodeLaunchDTO(json: """
        {
          "id": "launch-7",
          "name": "Mission G",
          "status": null,
          "window_start": "2026-05-12T10:00:00Z",
          "window_end": null,
          "image": null,
          "vid_urls": [],
          "rocket": null,
          "pad": { "id": null, "name": "LC-39A", "latitude": null, "longitude": null, "location": null },
          "mission": null
        }
        """)

        let mapped = LaunchDTOMapper.map(dto)

        #expect(mapped.launchPad?.name == "LC-39A")
        #expect(mapped.launchPad?.id.isEmpty == false)
        // A missing coordinate must stay `nil`, not fall back to (0, 0), a real, valid location.
        #expect(mapped.launchPad?.latitude == nil)
        #expect(mapped.launchPad?.longitude == nil)
    }

    @Test("Preserves a real (0, 0) pad coordinate instead of treating it as missing")
    static func preservesZeroCoordinateForPad() throws {
        let dto = try decodeLaunchDTO(json: """
        {
          "id": "launch-8",
          "name": "Mission H",
          "status": null,
          "window_start": "2026-05-12T10:00:00Z",
          "window_end": null,
          "image": null,
          "vid_urls": [],
          "rocket": null,
          "pad": { "id": 1, "name": "Equator Pad", "latitude": 0, "longitude": 0, "location": null },
          "mission": null
        }
        """)

        let mapped = LaunchDTOMapper.map(dto)

        #expect(mapped.launchPad?.latitude == 0)
        #expect(mapped.launchPad?.longitude == 0)
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

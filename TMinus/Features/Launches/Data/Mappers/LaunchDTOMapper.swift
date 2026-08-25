//
//  LaunchDTOMapper.swift
//  TMinus
//
//  Created by Sadegh on 06/05/2026.
//

import Foundation

enum LaunchDTOMapper {
    static func map(_ dto: LaunchDTO) -> Launch {
        Launch(
            id: dto.id,
            name: dto.name,
            status: mapStatus(dto.status),
            windowStart: dto.windowStart,
            windowEnd: dto.windowEnd,
            rocket: mapRocket(dto.rocket?.configuration, launchID: dto.id),
            launchPad: mapPad(dto.pad, launchID: dto.id),
            mission: mapMission(dto.mission, launchID: dto.id),
            imageURL: mapImageURL(dto.imageURL),
            webcastURL: mapWebcastURL(dto.videoURLs)
        )
    }

    /// Picks the lowest-`priority` entry among those that actually have a `url`, picking by
    /// priority first and only then checking `url` would silently drop a perfectly valid,
    /// lower-priority webcast link whenever the top-priority entry happens to have none.
    private static func mapWebcastURL(_ videoURLs: [LaunchVideoURLDTO]?) -> URL? {
        videoURLs?
            .filter { $0.url != nil }
            .min(by: { ($0.priority ?? .max) < ($1.priority ?? .max) })?
            .url
    }

    private static func mapImageURL(_ imageURLString: String?) -> URL? {
        LenientURLDecoding.url(from: imageURLString)
    }

    private static func mapStatus(_ status: LaunchStatusDTO?) -> LaunchStatus {
        guard let status else { return .unknown(nil) }

        let token = (status.abbrev ?? status.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Exact match against the known Launch Library 2 abbreviation codes first, safe
        // regardless of what a *future* status string happens to be, unlike the substring
        // fallback below (e.g. a hypothetical "Negotiating" status would substring-match "go"
        // there and misclassify). Only tokens that don't exactly match a known code fall through
        // to the heuristic.
        if let exact = Constants.knownStatusAbbreviations[token] {
            return exact
        }

        // Word-boundary heuristic, kept as a fallback for close variants of a known status (e.g.
        // "On Hold" or "TBD - Awaiting Date") that wouldn't exact-match above, matched against
        // whole words, not a raw substring, so a future/unmapped status whose name merely
        // *contains* one of these as part of a longer word (e.g. a hypothetical "Negotiating
        // Slot") can't be misclassified into it; only `.unknown(status.name)` falls back for
        // that, same as any other genuinely-unrecognized status. Order matters here since a
        // token could contain more than one of these words.
        let words = Set(token.split(whereSeparator: { $0.isLetter == false }))
        switch true {
        case words.contains("tbd"), words.contains("determined"):
            return .toBeDetermined
        case words.contains("hold"):
            return .hold
        case words.contains("success"):
            return .success
        case words.contains("fail"), words.contains("failure"):
            return .failure
        case words.contains("go"):
            return .go
        default:
            return .unknown(status.name ?? status.abbrev)
        }
    }

    /// Keeps a named nested entity even when its ID is missing. The launch ID provides a stable,
    /// collision-free fallback for list identity and persistence.
    private static func mapRocket(_ configuration: LaunchRocketConfigurationDTO?, launchID: String) -> LaunchRocket? {
        guard let configuration, configuration.id != nil || configuration.name != nil else { return nil }
        return LaunchRocket(
            id: configuration.id ?? Constants.unknownRocketID(for: launchID),
            name: configuration.name ?? L10n.Common.unknown
        )
    }

    private static func mapPad(_ pad: LaunchPadDTO?, launchID: String) -> LaunchPad? {
        guard let pad, pad.id != nil || pad.name != nil else { return nil }

        return LaunchPad(
            id: pad.id.map(String.init) ?? Constants.unknownPadID(for: launchID),
            name: pad.name ?? L10n.Common.unknown,
            latitude: pad.latitude,
            longitude: pad.longitude,
            locationName: pad.location?.name
        )
    }

    private static func mapMission(_ mission: LaunchMissionDTO?, launchID: String) -> LaunchMission? {
        guard let mission, mission.id != nil || mission.name != nil else { return nil }

        return LaunchMission(
            id: mission.id.map(String.init) ?? Constants.unknownMissionID(for: launchID),
            name: mission.name ?? L10n.Common.unknown,
            description: mission.description,
            type: mission.type,
            orbit: mission.orbit?.name
        )
    }
}

// MARK: - Constants

private extension LaunchDTOMapper {
    enum Constants {
        /// The Launch Library 2 API's known status abbreviation codes, lowercased, checked for
        /// an exact match before the substring heuristic in `mapStatus` runs.
        static let knownStatusAbbreviations: [String: LaunchStatus] = [
            "go": .go,
            "tbd": .toBeDetermined,
            "hold": .hold,
            "success": .success,
            "failure": .failure,
        ]

        /// Fallback identifiers used only when the API omits an id but still supplied a name,
        /// deterministic (not a random UUID, and not Swift's `String.hashValue`, which is
        /// randomly seeded per process launch and would churn the persisted id every relaunch)
        /// so re-fetching the same launch doesn't churn the locally persisted id on every save,
        /// while still being unique per launch, see the doc comment on `mapRocket` above.
        static func unknownPadID(for launchID: String) -> String { "unknown-pad-\(launchID)" }
        static func unknownMissionID(for launchID: String) -> String { "unknown-mission-\(launchID)" }

        /// `LaunchRocket.id` is `Int`, so the pad/mission approach above (embed `launchID`
        /// directly in a string id) doesn't apply, this hashes `launchID` into a negative `Int`
        /// instead, using a fixed, non-randomized algorithm (unlike `String.hashValue`) so the
        /// result is stable across app launches. Negative so it can never collide with a real
        /// rocket id, which the LL2 API always returns as a small positive integer.
        static func unknownRocketID(for launchID: String) -> Int {
            var hash: UInt64 = 0xcbf2_9ce4_8422_2325 // FNV-1a 64-bit offset basis
            for byte in launchID.utf8 {
                hash ^= UInt64(byte)
                hash = hash &* 0x0000_0100_0000_01B3 // FNV-1a 64-bit prime
            }
            return -Int(hash & 0x7FFF_FFFF_FFFF_FFFF) - 1
        }
    }
}

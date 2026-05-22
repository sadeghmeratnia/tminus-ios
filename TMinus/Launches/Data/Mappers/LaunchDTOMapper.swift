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
            rocket: dto.rocket?.configuration.map { LaunchRocket(id: $0.id, name: $0.name) },
            launchPad: mapPad(dto.pad),
            mission: mapMission(dto.mission),
            imageURL: mapImageURL(dto.imageURL),
            webcastURL: dto.videoURLs?.sorted(by: { ($0.priority ?? .max) < ($1.priority ?? .max) }).first?.url)
    }

    private static func mapImageURL(_ imageURLString: String?) -> URL? {
        guard let imageURLString else { return nil }
        let trimmed = imageURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        if let url = URL(string: trimmed) {
            return url
        }
        let escaped = trimmed.replacingOccurrences(of: " ", with: "%20")
        return URL(string: escaped)
    }

    private static func mapStatus(_ status: LaunchStatusDTO?) -> LaunchStatus {
        guard let status else { return .unknown(nil) }

        let token = (status.abbrev ?? status.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch token {
        case "go":
            return .go
        case "tbd", "to be determined":
            return .toBeDetermined
        case "hold":
            return .hold
        case "success":
            return .success
        case "failure", "fail":
            return .failure
        default:
            return .unknown(status.name ?? status.abbrev)
        }
    }

    private static func mapPad(_ pad: LaunchPadDTO?) -> LaunchPad? {
        guard let pad, let id = pad.id else { return nil }

        return LaunchPad(
            id: String(id),
            name: pad.name ?? "Unknown",
            latitude: pad.latitude ?? 0,
            longitude: pad.longitude ?? 0,
            locationName: pad.location?.name)
    }

    private static func mapMission(_ mission: LaunchMissionDTO?) -> LaunchMission? {
        guard let mission else { return nil }

        return LaunchMission(
            id: String(mission.id ?? -1),
            name: mission.name ?? "Unknown Mission",
            description: mission.description,
            type: mission.type,
            orbit: mission.orbit?.name)
    }
}

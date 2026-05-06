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
            rocket: mapRocket(dto.rocket),
            launchPad: mapPad(dto.pad),
            mission: mapMission(dto.mission),
            imageURL: dto.image,
            webcastURL: dto.videoURLs?.sorted(by: { ($0.priority ?? .max) < ($1.priority ?? .max) }).first?.url)
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

    private static func mapRocket(_ rocket: LaunchRocketDTO?) -> LaunchRocket {
        guard let configuration = rocket?.configuration else {
            return LaunchRocket(id: "unknown", name: "Unknown Rocket")
        }

        return LaunchRocket(id: configuration.id, name: configuration.name)
    }

    private static func mapPad(_ pad: LaunchPadDTO?) -> LaunchPad {
        let latitude = Double(pad?.latitude ?? "") ?? 0
        let longitude = Double(pad?.longitude ?? "") ?? 0

        return LaunchPad(
            id: String(pad?.id ?? -1),
            name: pad?.name ?? "Unknown Launch Pad",
            latitude: latitude,
            longitude: longitude,
            locationName: pad?.location?.name)
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

//
//  LaunchLocalModelMapper.swift
//  TMinus
//
//  Created by Sadegh on 19/05/2026.
//

import Foundation

// MARK: - LaunchLocalModelMapper

enum LaunchLocalModelMapper {
    static func map(_ launch: Launch, fetchedAt: Date = .now) -> LaunchLocalModel {
        let (statusCode, statusLabel) = mapStatus(launch.status)
        return LaunchLocalModel(
            id: launch.id,
            name: launch.name,
            statusCode: statusCode,
            statusLabel: statusLabel,
            windowStart: launch.windowStart,
            windowEnd: launch.windowEnd,
            rocketID: launch.rocket?.id,
            rocketName: launch.rocket?.name,
            padID: launch.launchPad?.id,
            padName: launch.launchPad?.name,
            padLatitude: launch.launchPad?.latitude,
            padLongitude: launch.launchPad?.longitude,
            padLocationName: launch.launchPad?.locationName,
            missionID: launch.mission?.id,
            missionName: launch.mission?.name,
            missionDescriptionText: launch.mission?.description,
            missionType: launch.mission?.type,
            missionOrbit: launch.mission?.orbit,
            imageURLString: launch.imageURL?.absoluteString,
            webcastURLString: launch.webcastURL?.absoluteString,
            fetchedAt: fetchedAt)
    }

    /// Updates an existing persisted model in place from a domain entity,
    /// avoiding the allocation of an intermediate model instance.
    static func update(_ model: LaunchLocalModel, from launch: Launch, fetchedAt: Date) {
        let (statusCode, statusLabel) = mapStatus(launch.status)
        model.name = launch.name
        model.statusCode = statusCode
        model.statusLabel = statusLabel
        model.windowStart = launch.windowStart
        model.windowEnd = launch.windowEnd
        model.rocketID = launch.rocket?.id
        model.rocketName = launch.rocket?.name
        model.padID = launch.launchPad?.id
        model.padName = launch.launchPad?.name
        model.padLatitude = launch.launchPad?.latitude
        model.padLongitude = launch.launchPad?.longitude
        model.padLocationName = launch.launchPad?.locationName
        model.missionID = launch.mission?.id
        model.missionName = launch.mission?.name
        model.missionDescriptionText = launch.mission?.description
        model.missionType = launch.mission?.type
        model.missionOrbit = launch.mission?.orbit
        model.imageURLString = launch.imageURL?.absoluteString
        model.webcastURLString = launch.webcastURL?.absoluteString
        model.fetchedAt = fetchedAt
    }

    static func map(_ model: LaunchLocalModel) -> Launch {
        Launch(
            id: model.id,
            name: model.name,
            status: mapStatus(code: model.statusCode, label: model.statusLabel),
            windowStart: model.windowStart,
            windowEnd: model.windowEnd,
            rocket: mapRocket(model),
            launchPad: mapLaunchPad(model),
            mission: mapMission(model),
            imageURL: model.imageURLString.flatMap(URL.init(string:)),
            webcastURL: model.webcastURLString.flatMap(URL.init(string:)))
    }
}

extension LaunchLocalModelMapper {
    fileprivate static func mapStatus(_ status: LaunchStatus) -> (String, String?) {
        switch status {
        case .go:
            return ("go", nil)
        case .toBeDetermined:
            return ("tbd", nil)
        case .hold:
            return ("hold", nil)
        case .success:
            return ("success", nil)
        case .failure:
            return ("failure", nil)
        case let .unknown(label):
            return ("unknown", label)
        }
    }

    fileprivate static func mapStatus(code: String, label: String?) -> LaunchStatus {
        switch code {
        case "go":
            return .go
        case "tbd":
            return .toBeDetermined
        case "hold":
            return .hold
        case "success":
            return .success
        case "failure":
            return .failure
        default:
            return .unknown(label)
        }
    }

    fileprivate static func mapRocket(_ model: LaunchLocalModel) -> LaunchRocket? {
        guard let id = model.rocketID, let name = model.rocketName else { return nil }
        return LaunchRocket(id: id, name: name)
    }

    fileprivate static func mapLaunchPad(_ model: LaunchLocalModel) -> LaunchPad? {
        guard let id = model.padID, let name = model.padName else { return nil }
        return LaunchPad(
            id: id,
            name: name,
            latitude: model.padLatitude ?? 0,
            longitude: model.padLongitude ?? 0,
            locationName: model.padLocationName)
    }

    fileprivate static func mapMission(_ model: LaunchLocalModel) -> LaunchMission? {
        guard let missionID = model.missionID,
              let missionName = model.missionName else {
            return nil
        }
        return LaunchMission(
            id: missionID,
            name: missionName,
            description: model.missionDescriptionText,
            type: model.missionType,
            orbit: model.missionOrbit)
    }
}

//
//  LaunchLocalModelMapper.swift
//  TMinus
//
//  Created by Sadegh on 19/05/2026.
//

import Foundation

// MARK: - LaunchLocalModelMapper

enum LaunchLocalModelMapper {
    /// The persisted `statusCode` values meaning a launch is resolved (flown, one way or the
    /// other) rather than still pending, shared with `SwiftDataLaunchLocalDataSource`'s
    /// upcoming/previous predicates. Derived from `PersistedStatusCode` (the same source
    /// `mapStatus(_:)`/`mapStatus(code:label:)` below read and write) rather than duplicated as
    /// independent string literals, so the two can't drift out of sync with what's actually
    /// persisted to disk.
    static let resolvedStatusCodes: Set<String> = [
        PersistedStatusCode.success.rawValue,
        PersistedStatusCode.failure.rawValue,
    ]

    /// The persisted `statusCode` for a `LaunchStatus.unknown`, a status the API returned that
    /// `mapStatus(_:)` below doesn't recognize (e.g. a real Launch Library value like
    /// "Partial Failure" or "In Flight" outside the cases it maps). Shared with
    /// `SwiftDataLaunchLocalDataSource` so its upcoming/previous split can fall back to a
    /// `windowStart` comparison for exactly this ambiguous case.
    static let unknownStatusCode = PersistedStatusCode.unknown.rawValue

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
            fetchedAt: fetchedAt
        )
    }

    /// Updates an existing persisted model in place from a domain entity,
    /// avoiding the allocation of an intermediate model instance.
    static func update(_ model: LaunchLocalModel, from launch: Launch, fetchedAt: Date) {
        let (statusCode, statusLabel) = mapStatus(launch.status)
        model.name = launch.name
        model.nameLowercased = launch.name.localizedLowercase
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
            webcastURL: model.webcastURLString.flatMap(URL.init(string:))
        )
    }
}

/// The persisted form of `LaunchStatus`, spelled out once so `mapStatus(_:)` (encode) and
/// `mapStatus(code:label:)` (decode), plus `resolvedStatusCodes`/`unknownStatusCode` above,
/// all read from the same set of string literals instead of independently duplicating them,
/// which is what let the two previously drift out of sync silently.
private enum PersistedStatusCode: String {
    case go
    case tbd
    case hold
    case success
    case failure
    case unknown
}

private extension LaunchLocalModelMapper {
    static func mapStatus(_ status: LaunchStatus) -> (String, String?) {
        switch status {
        case .go:
            return (PersistedStatusCode.go.rawValue, nil)
        case .toBeDetermined:
            return (PersistedStatusCode.tbd.rawValue, nil)
        case .hold:
            return (PersistedStatusCode.hold.rawValue, nil)
        case .success:
            return (PersistedStatusCode.success.rawValue, nil)
        case .failure:
            return (PersistedStatusCode.failure.rawValue, nil)
        case let .unknown(label):
            return (PersistedStatusCode.unknown.rawValue, label)
        }
    }

    static func mapStatus(code: String, label: String?) -> LaunchStatus {
        switch PersistedStatusCode(rawValue: code) {
        case .go:
            return .go
        case .tbd:
            return .toBeDetermined
        case .hold:
            return .hold
        case .success:
            return .success
        case .failure:
            return .failure
        case .unknown, nil:
            return .unknown(label)
        }
    }

    static func mapRocket(_ model: LaunchLocalModel) -> LaunchRocket? {
        guard let id = model.rocketID, let name = model.rocketName else { return nil }
        return LaunchRocket(id: id, name: name)
    }

    static func mapLaunchPad(_ model: LaunchLocalModel) -> LaunchPad? {
        guard let id = model.padID, let name = model.padName else { return nil }
        return LaunchPad(
            id: id,
            name: name,
            latitude: model.padLatitude,
            longitude: model.padLongitude,
            locationName: model.padLocationName
        )
    }

    static func mapMission(_ model: LaunchLocalModel) -> LaunchMission? {
        guard let missionID = model.missionID,
              let missionName = model.missionName
        else {
            return nil
        }
        return LaunchMission(
            id: missionID,
            name: missionName,
            description: model.missionDescriptionText,
            type: model.missionType,
            orbit: model.missionOrbit
        )
    }
}

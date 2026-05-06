//
//  Launch.swift
//  TMinus
//
//  Created by Sadegh on 06/05/2026.
//

import Foundation

// MARK: - Launch

struct Launch: Equatable, Identifiable {
    let id: String
    let name: String
    let status: LaunchStatus
    let windowStart: Date
    let windowEnd: Date?
    let rocket: LaunchRocket
    let launchPad: LaunchPad
    let mission: LaunchMission?
    let imageURL: URL?
    let webcastURL: URL?
}

// MARK: - LaunchStatus

enum LaunchStatus: Equatable {
    case go
    case toBeDetermined
    case hold
    case success
    case failure
    case unknown(String?)
}

// MARK: - LaunchRocket

struct LaunchRocket: Equatable {
    let id: String
    let name: String
}

// MARK: - LaunchPad

struct LaunchPad: Equatable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let locationName: String?
}

// MARK: - LaunchMission

struct LaunchMission: Equatable {
    let id: String
    let name: String
    let description: String?
    let type: String?
    let orbit: String?
}

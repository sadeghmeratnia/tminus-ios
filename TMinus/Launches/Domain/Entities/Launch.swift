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

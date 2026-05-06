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
    let image: URL?
    let videoURLs: [LaunchVideoURLDTO]?
    let rocket: LaunchRocketDTO?
    let pad: LaunchPadDTO?
    let mission: LaunchMissionDTO?

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
}

// MARK: - LaunchStatusDTO

struct LaunchStatusDTO: Decodable {
    let name: String?
    let abbrev: String?
}

// MARK: - LaunchVideoURLDTO

struct LaunchVideoURLDTO: Decodable {
    let url: URL?
    let priority: Int?
}

// MARK: - LaunchRocketDTO

struct LaunchRocketDTO: Decodable {
    let configuration: LaunchRocketConfigurationDTO?
}

// MARK: - LaunchRocketConfigurationDTO

struct LaunchRocketConfigurationDTO: Decodable {
    let id: String
    let name: String
}

// MARK: - LaunchPadDTO

struct LaunchPadDTO: Decodable {
    let id: Int?
    let name: String?
    let latitude: String?
    let longitude: String?
    let location: LaunchPadLocationDTO?
}

// MARK: - LaunchPadLocationDTO

struct LaunchPadLocationDTO: Decodable {
    let name: String?
}

// MARK: - LaunchMissionDTO

struct LaunchMissionDTO: Decodable {
    let id: Int?
    let name: String?
    let description: String?
    let type: String?
    let orbit: LaunchMissionOrbitDTO?
}

// MARK: - LaunchMissionOrbitDTO

struct LaunchMissionOrbitDTO: Decodable {
    let name: String?
}

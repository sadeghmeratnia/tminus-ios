//
//  LaunchMissionDTO.swift
//  TMinus
//
//  Created by Sadegh on 07/05/2026.
//

import Foundation

struct LaunchMissionDTO: Decodable, Sendable {
    let id: Int?
    let name: String?
    let description: String?
    let type: String?
    let orbit: LaunchMissionOrbitDTO?
}

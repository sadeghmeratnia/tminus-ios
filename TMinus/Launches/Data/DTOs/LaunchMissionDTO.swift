//
//  LaunchMissionDTO.swift
//  TMinus
//
//  Created by Sadegh on 07/05/2026.
//

import Foundation

struct LaunchMissionDTO: Decodable {
    let id: Int?
    let name: String?
    let description: String?
    let type: String?
    let orbit: LaunchMissionOrbitDTO?
}

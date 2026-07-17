//
//  LaunchPadDTO.swift
//  TMinus
//
//  Created by Sadegh on 07/05/2026.
//

import Foundation

struct LaunchPadDTO: Decodable {
    let id: Int?
    let name: String?
    let latitude: Double?
    let longitude: Double?
    let location: LaunchPadLocationDTO?
}

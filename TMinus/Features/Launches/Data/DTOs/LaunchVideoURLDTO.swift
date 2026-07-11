//
//  LaunchVideoURLDTO.swift
//  TMinus
//
//  Created by Sadegh on 07/05/2026.
//

import Foundation

struct LaunchVideoURLDTO: Decodable, Sendable {
    let url: URL?
    let priority: Int?
}

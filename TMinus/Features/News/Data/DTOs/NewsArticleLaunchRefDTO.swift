//
//  NewsArticleLaunchRefDTO.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import Foundation

struct NewsArticleLaunchRefDTO: Decodable {
    let launchID: String

    private enum CodingKeys: String, CodingKey {
        case launchID = "launchId"
    }
}

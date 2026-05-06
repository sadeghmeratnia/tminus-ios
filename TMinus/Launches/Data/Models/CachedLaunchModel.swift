//
//  CachedLaunchModel.swift
//  TMinus
//
//  Created by Sadegh on 06/05/2026.
//

import SwiftData
import Foundation

@Model
final class CachedLaunchModel {
    @Attribute(.unique) var id: String
    var payload: Data
    var fetchedAt: Date

    init(id: String, payload: Data, fetchedAt: Date = .now) {
        self.id = id
        self.payload = payload
        self.fetchedAt = fetchedAt
    }
}

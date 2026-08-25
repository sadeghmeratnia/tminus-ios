//
//  LaunchLocalModel.swift
//  TMinus
//
//  Created by Sadegh on 19/05/2026.
//

import Foundation
import SwiftData

@Model
final class LaunchLocalModel {
    @Attribute(.unique) var id: String
    var name: String
    /// Kept alongside `name` specifically so search can match with `String.contains` (a plain
    /// substring check, translated to a simple SQL `LIKE`) instead of `.localizedStandardContains`
    ///, the latter compiles to a `#Predicate` that invokes CoreData/SQLite's ICU-based collation
    /// search, which has a real, reproducible SIGSEGV (`_NSCoreDataStringSearch`) when two such
    /// fetches execute concurrently, even across unrelated `ModelContainer`s. Both sides of the
    /// comparison are lowercased (this field at write time, the search term at query time) so
    /// case-insensitivity doesn't depend on ICU collation at all.
    var nameLowercased: String
    var statusCode: String
    var statusLabel: String?
    var windowStart: Date
    var windowEnd: Date?
    var rocketID: Int?
    var rocketName: String?
    var padID: String?
    var padName: String?
    var padLatitude: Double?
    var padLongitude: Double?
    var padLocationName: String?
    var missionID: String?
    var missionName: String?
    var missionDescriptionText: String?
    var missionType: String?
    var missionOrbit: String?
    var imageURLString: String?
    var webcastURLString: String?
    var fetchedAt: Date

    init(id: String,
         name: String,
         statusCode: String,
         statusLabel: String?,
         windowStart: Date,
         windowEnd: Date?,
         rocketID: Int?,
         rocketName: String?,
         padID: String?,
         padName: String?,
         padLatitude: Double?,
         padLongitude: Double?,
         padLocationName: String?,
         missionID: String?,
         missionName: String?,
         missionDescriptionText: String?,
         missionType: String?,
         missionOrbit: String?,
         imageURLString: String?,
         webcastURLString: String?,
         fetchedAt: Date = .now)
    {
        self.id = id
        self.name = name
        nameLowercased = name.localizedLowercase
        self.statusCode = statusCode
        self.statusLabel = statusLabel
        self.windowStart = windowStart
        self.windowEnd = windowEnd
        self.rocketID = rocketID
        self.rocketName = rocketName
        self.padID = padID
        self.padName = padName
        self.padLatitude = padLatitude
        self.padLongitude = padLongitude
        self.padLocationName = padLocationName
        self.missionID = missionID
        self.missionName = missionName
        self.missionDescriptionText = missionDescriptionText
        self.missionType = missionType
        self.missionOrbit = missionOrbit
        self.imageURLString = imageURLString
        self.webcastURLString = webcastURLString
        self.fetchedAt = fetchedAt
    }
}

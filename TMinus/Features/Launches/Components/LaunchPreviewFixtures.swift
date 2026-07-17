//
//  LaunchPreviewFixtures.swift
//  TMinus
//
//  Created by Sadegh on 28/05/2026.
//

import Foundation

enum LaunchPreviewFixtures {
    static let launchID = "preview-1"

    static let launch = Launch(
        id: launchID,
        name: "Starlink Group 6-50",
        status: .go,
        windowStart: Date(timeIntervalSince1970: 1_735_689_600),
        windowEnd: nil,
        rocket: LaunchRocket(id: 1, name: "Falcon 9 Block 5"),
        launchPad: LaunchPad(
            id: "10",
            name: "SLC-40",
            latitude: 28.5,
            longitude: -80.5,
            locationName: "Cape Canaveral"),
        mission: LaunchMission(
            id: "1",
            name: "Starlink",
            description: "Dedicated Starlink mission.",
            type: "Communications",
            orbit: "Low Earth Orbit"),
        imageURL: nil,
        webcastURL: nil)

    static let listLoadedState = LaunchListState(
        mode: .upcoming,
        launches: [launch],
        pagination: .initial,
        phase: .loaded)

    static let detailLoadedState = LaunchDetailState(
        launchID: launchID,
        launch: launch,
        phase: .loaded,
        relatedArticles: [NewsPreviewFixtures.article],
        loadGeneration: LoadGeneration(current: 1))
}

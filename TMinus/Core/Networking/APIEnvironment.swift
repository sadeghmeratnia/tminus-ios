//
//  APIEnvironment.swift
//  TMinus
//
//  Created by Sadegh on 22/04/2026.
//

import Foundation

// MARK: - APIEnvironment

struct APIEnvironment {
    let launchLibraryBaseURL: URL
    let spaceflightNewsBaseURL: URL
}

// MARK: - Environments

extension APIEnvironment {
    static let production = APIEnvironment(
        launchLibraryBaseURL: URL(string: "https://ll.thespacedevs.com/2.3.0/")!,
        spaceflightNewsBaseURL: URL(string: "https://api.spaceflightnewsapi.net/v4/")!)

    static let development = APIEnvironment(
        launchLibraryBaseURL: URL(string: "https://lldev.thespacedevs.com/2.3.0/")!,
        spaceflightNewsBaseURL: URL(string: "https://api.spaceflightnewsapi.net/v4/")!)

    static let current: APIEnvironment = {
        #if DEBUG
            return .development
        #else
            return .production
        #endif
    }()
}

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
        launchLibraryBaseURL: makeURL("https://ll.thespacedevs.com/2.3.0/"),
        spaceflightNewsBaseURL: makeURL("https://api.spaceflightnewsapi.net/v4/"))

    static let development = APIEnvironment(
        launchLibraryBaseURL: makeURL("https://lldev.thespacedevs.com/2.3.0/"),
        spaceflightNewsBaseURL: makeURL("https://api.spaceflightnewsapi.net/v4/"))

    static let current: APIEnvironment = {
        #if DEBUG
            return .development
        #else
            return .production
        #endif
    }()

    /// Hardcoded API base URLs can only ever fail to parse due to an authoring typo — this
    /// fails fast with a clear message instead of the generic trap a bare `!` would produce.
    /// `APIEnvironmentTests` also asserts every literal here parses, so a typo is caught by
    /// the test suite before it would ever reach this fatalError at runtime.
    private static func makeURL(_ string: StaticString) -> URL {
        guard let url = URL(string: "\(string)") else {
            fatalError("Invalid hardcoded API base URL literal: \(string)")
        }
        return url
    }
}

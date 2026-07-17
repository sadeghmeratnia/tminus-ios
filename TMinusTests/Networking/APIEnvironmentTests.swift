//
//  APIEnvironmentTests.swift
//  TMinusTests
//
//  Created by Sadegh on 13/07/2026.
//

@testable import TMinus
import Testing
import Foundation

@Suite("APIEnvironment")
enum APIEnvironmentTests {
    @Test("Production URLs are valid HTTPS endpoints")
    static func productionURLsAreValid() {
        #expect(APIEnvironment.production.launchLibraryBaseURL.scheme == "https")
        #expect(APIEnvironment.production.launchLibraryBaseURL.host == "ll.thespacedevs.com")
        #expect(APIEnvironment.production.spaceflightNewsBaseURL.scheme == "https")
        #expect(APIEnvironment.production.spaceflightNewsBaseURL.host == "api.spaceflightnewsapi.net")
    }

    @Test("Development URLs are valid HTTPS endpoints")
    static func developmentURLsAreValid() {
        #expect(APIEnvironment.development.launchLibraryBaseURL.scheme == "https")
        #expect(APIEnvironment.development.launchLibraryBaseURL.host == "lldev.thespacedevs.com")
        #expect(APIEnvironment.development.spaceflightNewsBaseURL.scheme == "https")
        #expect(APIEnvironment.development.spaceflightNewsBaseURL.host == "api.spaceflightnewsapi.net")
    }

    @Test("current resolves to a valid environment for the active build configuration")
    static func currentIsValid() {
        #expect(APIEnvironment.current.launchLibraryBaseURL.scheme == "https")
        #expect(APIEnvironment.current.spaceflightNewsBaseURL.scheme == "https")
    }
}

//
//  LaunchesEndpointTests.swift
//  TMinusTests
//
//  Created by Sadegh on 17/08/2026.
//

import Foundation
import Testing
@testable import TMinus

@Suite("LaunchesEndpoint")
struct LaunchesEndpointTests {
    @Test("Computes offset from page and limit")
    func computesOffset() throws {
        let endpoint = LaunchesEndpoint.upcoming(query: LaunchListQuery(page: 3, limit: 10))
        let items = try queryItems(for: endpoint)

        #expect(items["offset"] == "20")
        #expect(items["limit"] == "10")
    }

    @Test("Page 1 has zero offset")
    func firstPageHasZeroOffset() throws {
        let endpoint = LaunchesEndpoint.upcoming(query: LaunchListQuery(page: 1, limit: 20))
        let items = try queryItems(for: endpoint)

        #expect(items["offset"] == "0")
    }

    @Test("Clamps a non-positive page or limit to 1 rather than producing a negative offset")
    func clampsNonPositivePageAndLimit() throws {
        let endpoint = LaunchesEndpoint.upcoming(query: LaunchListQuery(page: 0, limit: -5))
        let items = try queryItems(for: endpoint)

        #expect(items["offset"] == "0")
        #expect(items["limit"] == "1")
    }

    @Test("Upcoming orders by ascending window start, previous by descending")
    func setsExpectedOrdering() throws {
        let upcomingItems = try queryItems(for: LaunchesEndpoint.upcoming(query: LaunchListQuery()))
        let previousItems = try queryItems(for: LaunchesEndpoint.previous(query: LaunchListQuery()))

        #expect(upcomingItems["ordering"] == "window_start")
        #expect(previousItems["ordering"] == "-window_start")
    }

    @Test("Omits the search query item entirely when search text is empty")
    func omitsSearchWhenEmpty() throws {
        let endpoint = LaunchesEndpoint.upcoming(query: LaunchListQuery(searchText: nil))
        let request = try endpoint.urlRequest()
        let components = try URLComponents(url: #require(request.url), resolvingAgainstBaseURL: false)

        #expect(components?.queryItems?.contains { $0.name == "search" } == false)
    }

    @Test("Includes the search query item when search text is non-empty")
    func includesSearchWhenPresent() throws {
        let endpoint = LaunchesEndpoint.upcoming(query: LaunchListQuery(searchText: "starship"))
        let items = try queryItems(for: endpoint)

        #expect(items["search"] == "starship")
    }
}

private extension LaunchesEndpointTests {
    func queryItems(for endpoint: Endpoint) throws -> [String: String] {
        let request = try endpoint.urlRequest()
        let components = try URLComponents(url: #require(request.url), resolvingAgainstBaseURL: false)
        var result: [String: String] = [:]
        for item in components?.queryItems ?? [] {
            result[item.name] = item.value
        }
        return result
    }
}

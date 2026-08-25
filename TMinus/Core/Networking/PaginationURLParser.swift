//
//  PaginationURLParser.swift
//  TMinus
//
//  Created by Sadegh on 01/07/2026.
//

import Foundation
import OSLog

// MARK: - PaginationURLParser

enum PaginationURLParser {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "app",
        category: "PaginationURLParser"
    )

    /// Assumes `offset` is a clean multiple of `limit`, which both APIs this app talks to always
    /// produce for their own `next`/`previous` links, if that ever weren't true, integer
    /// division here would silently round down to the enclosing page rather than fail loudly.
    /// This is server-controlled data, not something the app can validate ahead of time, so a
    /// mismatch is logged rather than asserted: a legitimate-but-unusual response (a changed
    /// default page size, an odd last page) should degrade to a slightly-off page number, not
    /// crash every debug/QA/test build.
    static func pageNumber(from urlString: String?, fallbackLimit: Int) -> Int? {
        guard let urlString,
              let components = URLComponents(string: urlString),
              let queryItems = components.queryItems
        else { return nil }

        let safeLimit = max(1, fallbackLimit)
        let offset = queryItems.first(where: { $0.name == "offset" })
            .flatMap { Int($0.value ?? "") } ?? 0
        let limit = queryItems.first(where: { $0.name == "limit" })
            .flatMap { Int($0.value ?? "") }
            .flatMap { $0 > 0 ? $0 : nil } ?? safeLimit

        // A negative offset can't correspond to any real page, unlike the "not a clean multiple
        // of limit" case below, there's no reasonable page number to round down to, so this is
        // treated as "no further page" rather than let `(offset / limit) + 1` hand back `0` or a
        // negative page number to a caller (`PagedResult.nextPage`/`.previousPage`) that assumes
        // page numbers are always positive.
        guard offset >= 0 else {
            logger.warning("Pagination offset \(offset) is negative — treating as no further page. urlString=\(urlString, privacy: .public)")
            return nil
        }

        if offset.isMultiple(of: limit) == false {
            logger.warning("Pagination offset \(offset) isn't a multiple of limit \(limit) — page math will round down. urlString=\(urlString, privacy: .public)")
        }

        return (offset / limit) + 1
    }
}

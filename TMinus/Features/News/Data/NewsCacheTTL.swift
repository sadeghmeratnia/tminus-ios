//
//  NewsCacheTTL.swift
//  TMinus
//
//  Created by Sadegh on 09/07/2026.
//

import Foundation

enum NewsCacheTTL {
    /// Deliberately between `LaunchCacheTTL.upcoming` (120s) and `.previous` (900s), news
    /// articles are published less frequently than an upcoming launch's countdown data changes,
    /// but more frequently than a past launch's (effectively immutable) record does, so 5 minutes
    /// sits between the two rather than matching either.
    static let list: TimeInterval = 300
    static let detail: TimeInterval = 1800
    static let related: TimeInterval = 1800
}

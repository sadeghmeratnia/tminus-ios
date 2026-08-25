//
//  ListPageSize.swift
//  TMinus
//

import Foundation

// MARK: - ListPageSize

/// The page size every paginated list in this app requests, shared so a future change to it
/// doesn't have to be made, and kept in sync, in four places: `LaunchListQuery`/`NewsListQuery`'s
/// own defaults, plus `LaunchListViewModel`/`NewsListViewModel`'s explicit call-site arguments
/// (which previously re-hardcoded the same literal `20` instead of relying on the query types'
/// defaults).
enum ListPageSize {
    static let `default` = 20
}

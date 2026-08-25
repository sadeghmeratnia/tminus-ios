//
//  StackCoordinator.swift
//  TMinus
//
//  Created by Sadegh on 13/08/2026.
//

import Combine
import SwiftUI

/// Base class for any feature coordinator that owns a single `NavigationStack`'s push/pop state.
/// `LaunchesCoordinator` and `NewsCoordinator` were previously two independent, structurally
/// identical implementations of exactly this (`@Published var path`, a `push`-equivalent method,
/// nothing else navigation-related); this is that shared mechanism, leaving each feature
/// coordinator to add only what's actually feature-specific, its builders and
/// `destinationView(for:)`.
@MainActor
class StackCoordinator<Destination: Hashable>: ObservableObject {
    @Published var path = NavigationPath()

    /// `NavigationPath` doesn't expose its elements for inspection, so we track the
    /// destination/depth of the last push ourselves purely to reject an immediate repeat
    /// (e.g. a double-tap on a list row triggering `push` twice before the first navigation
    /// transition starts). If the path's depth has changed since, a pop, or any other
    /// push, the check no longer applies and the push proceeds normally.
    private var lastPushedDestination: Destination?
    private var lastPushedPathCount: Int?

    func push(_ destination: Destination) {
        if lastPushedDestination == destination, lastPushedPathCount == path.count {
            return
        }
        path.append(destination)
        lastPushedDestination = destination
        lastPushedPathCount = path.count
    }
}

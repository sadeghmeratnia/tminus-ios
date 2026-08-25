//
//  DetailLoadTaskKind.swift
//  TMinus
//
//  Created by Sadegh on 23/07/2026.
//

import Foundation

// MARK: - DetailLoadTaskKind

/// Identifies the two independent workloads a detail screen can run concurrently: the main
/// content load, and a best-effort secondary load (e.g. related articles) that must never cancel
/// or be cancelled by the main load. Each key only ever supersedes itself, unlike
/// `ListLoadKind`, where starting a fresh load also cancels a pending load-more, a detail
/// screen's two workloads are fully independent. Shared so every detail ViewModel gets the same
/// `TaskCoordinator` bookkeeping as list ViewModels instead of hand-rolling `Task` properties and
/// a matching `deinit`.
enum DetailLoadTaskKind: Hashable {
    case main
    case secondary

    var cancels: Set<DetailLoadTaskKind> {
        [self]
    }
}

extension DetailLoadTaskKind: TaskCancellationKind {}

// MARK: - DetailLoadTaskCoordinator

/// `TaskCoordinator` specialised for detail screens, keyed by `DetailLoadTaskKind`.
typealias DetailLoadTaskCoordinator = TaskCoordinator<DetailLoadTaskKind>

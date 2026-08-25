//
//  ListLoadTaskCoordinator.swift
//  TMinus
//
//  Created by Sadegh on 23/07/2026.
//

import Foundation

// MARK: - TaskCancellationKind

/// Identifies a ViewModel task and the other tasks it supersedes.
///
/// This is `Sendable` because `TaskCoordinator` reads its task dictionary from `deinit`, outside
/// the main actor's isolation.
protocol TaskCancellationKind: Hashable, Sendable {
    /// Tasks to cancel before starting this one. This usually includes `self`.
    var cancels: Set<Self> { get }
}

// MARK: - TaskCoordinator

/// Tracks a ViewModel's in-flight tasks and cancels work that a new task supersedes.
@MainActor
final class TaskCoordinator<Kind: TaskCancellationKind> {
    /// The ID prevents an older task from clearing a newer task stored under the same key.
    private var tasks: [Kind: (id: UUID, task: Task<Void, Never>)] = [:]

    deinit {
        tasks.values.forEach { $0.task.cancel() }
    }

    /// Cancels superseded work, then starts and tracks a task without retaining its owner.
    /// The returned task lets callers such as `.refreshable` wait for the load to finish.
    @discardableResult
    func start<Owner: AnyObject>(_ kind: Kind,
                                 owner: Owner,
                                 operation: @escaping @MainActor (Owner) async -> Void) -> Task<Void, Never>
    {
        kind.cancels.forEach {
            tasks[$0]?.task.cancel()
            tasks[$0] = nil
        }
        let id = UUID()
        let task = Task { [weak self, weak owner] in
            if let owner {
                await operation(owner)
            }
            // Only clear this task's own entry. A newer task may already occupy the same slot.
            if self?.tasks[kind]?.id == id {
                self?.tasks[kind] = nil
            }
        }
        tasks[kind] = (id: id, task: task)
        return task
    }

    /// Cancels all tracked work, usually when the owning view disappears. Generation checks keep
    /// late responses from updating state even if a shared network request continues running.
    func cancelAll() {
        tasks.values.forEach { $0.task.cancel() }
        tasks.removeAll()
    }
}

// MARK: - ListLoadTaskCoordinator

/// `TaskCoordinator` specialised for paginated list screens, keyed by `ListLoadKind`.
typealias ListLoadTaskCoordinator = TaskCoordinator<ListLoadKind>

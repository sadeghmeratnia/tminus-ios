//
//  ListLoadTaskCoordinatorTests.swift
//  TMinusTests
//
//  Created by Sadegh on 18/08/2026.
//

import Testing
@testable import TMinus

/// `TaskCoordinator` (aliased as `ListLoadTaskCoordinator`/`DetailLoadTaskCoordinator`) is the one
/// piece of shared code behind every list/detail screen's cancel-on-supersede and
/// cancel-on-deinit behaviour. Until now it was only exercised indirectly through ViewModel-level
/// timing tests, a regression in the `id`-guarded slot-clearing race, the `cancels` cancellation
/// itself, or the weak-owner capture would only have surfaced as a flaky, hard-to-diagnose
/// ViewModel test failure rather than a direct one here.
@Suite("TaskCoordinator")
@MainActor
struct ListLoadTaskCoordinatorTests {
    private final class Owner {}

    @Test("Starting a fresh load cancels an in-flight load-more, per ListLoadKind.cancels")
    func freshLoadCancelsInFlightLoadMore() async {
        let coordinator = ListLoadTaskCoordinator()
        let owner = Owner()
        let started = StartSignal()
        let outcome = ValueBox<Bool?>(nil)

        // `start`'s own returned `Task` is awaited directly (`await loadMoreTask.value`) rather
        // than racing a blind `Task.sleep` against it, `.value` only resolves once the
        // operation closure has actually finished running (cancelled or not, since it's cooperative
        // and this closure doesn't throw), so there's no timing window to get unlucky in.
        let loadMoreTask = coordinator.start(.loadMore, owner: owner) { _ in
            await started.markStarted()
            try? await Task.sleep(for: .milliseconds(30))
            await outcome.set(Task.isCancelled)
        }
        await started.waitForStart()

        coordinator.start(.fresh, owner: owner) { _ in }
        await loadMoreTask.value

        #expect(await outcome.value == true)
    }

    @Test("Starting a load-more does not cancel an in-flight fresh load")
    func loadMoreDoesNotCancelInFlightFreshLoad() async {
        let coordinator = ListLoadTaskCoordinator()
        let owner = Owner()
        let started = StartSignal()
        let outcome = ValueBox<Bool?>(nil)

        let freshTask = coordinator.start(.fresh, owner: owner) { _ in
            await started.markStarted()
            try? await Task.sleep(for: .milliseconds(30))
            await outcome.set(Task.isCancelled)
        }
        await started.waitForStart()

        coordinator.start(.loadMore, owner: owner) { _ in }
        await freshTask.value

        #expect(await outcome.value == false)
    }

    @Test("cancelAll cancels every currently-tracked task")
    func cancelAllCancelsEveryTrackedTask() async {
        let coordinator = ListLoadTaskCoordinator()
        let owner = Owner()
        let freshStarted = StartSignal()
        let freshOutcome = ValueBox<Bool?>(nil)

        // `.loadMore` is started first and would normally be cancelled by `.fresh` anyway per
        // `ListLoadKind.cancels`, starting `.fresh` first instead, so both entries are only
        // still tracked because of `cancelAll()`, not because `.fresh`'s own start superseded it.
        let freshTask = coordinator.start(.fresh, owner: owner) { _ in
            await freshStarted.markStarted()
            try? await Task.sleep(for: .milliseconds(30))
            await freshOutcome.set(Task.isCancelled)
        }
        await freshStarted.waitForStart()

        coordinator.cancelAll()
        await freshTask.value

        #expect(await freshOutcome.value == true)
    }

    @Test("A cancelled task's operation body never runs once its owner has deallocated")
    func operationDoesNotRunAfterOwnerDeallocates() async {
        let coordinator = ListLoadTaskCoordinator()
        let ran = ValueBox(false)
        let task: Task<Void, Never>

        do {
            let owner = Owner()
            // `start` captures `owner` weakly and resolves it only once the task actually runs,
            // deallocating it here, before the task body ever gets scheduled, exercises that path.
            task = coordinator.start(.fresh, owner: owner) { _ in
                await ran.set(true)
            }
        }

        await task.value
        #expect(await ran.value == false)
    }
}

// MARK: - Test helpers

/// Actor-isolated one-shot signal so a test can deterministically wait for a started `Task`'s
/// operation closure to actually begin running before racing a second `start` against it,
/// without this, "start A, then start B to supersede it" would be a flaky race against A's own
/// `Task` even being scheduled yet.
private actor StartSignal {
    private var continuation: CheckedContinuation<Void, Never>?
    private var hasStarted = false

    func markStarted() {
        hasStarted = true
        continuation?.resume()
        continuation = nil
    }

    func waitForStart() async {
        if hasStarted { return }
        await withCheckedContinuation { continuation = $0 }
    }
}

private actor ValueBox<Value: Sendable> {
    private(set) var value: Value

    init(_ value: Value) {
        self.value = value
    }

    func set(_ newValue: Value) {
        value = newValue
    }
}

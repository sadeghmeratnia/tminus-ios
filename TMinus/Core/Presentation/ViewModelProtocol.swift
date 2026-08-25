//
//  ViewModelProtocol.swift
//  TMinus
//
//  Created by Sadegh on 07/05/2026.
//

import Combine

@MainActor
protocol ViewModelProtocol: ObservableObject {
    associatedtype State
    associatedtype Trigger

    var state: State { get }
    func onTrigger(_ trigger: Trigger)

    /// Cancels any work this ViewModel currently has in flight. Views call this from
    /// `.onDisappear` so navigating away actually stops an in-progress network request instead of
    /// letting it run to completion in the background, see `TaskCoordinator.cancelAll()` for why
    /// that doesn't already happen for free via `deinit`. Defaults to a no-op for ViewModels with
    /// nothing to cancel (e.g. `StaticViewModel`).
    func cancelInFlightWork()

    /// Triggers a refresh and suspends until the load it starts (if any) finishes. `.refreshable`
    /// needs an `async` closure that stays open for the refresh's actual duration, calling
    /// `onTrigger(.refresh)` alone returns instantly, since the resulting load runs as an
    /// untracked background `Task`, which snaps the native pull-to-refresh spinner back before
    /// any network call has even started. Defaults to firing `onTrigger`-equivalent behaviour
    /// with nothing to await (e.g. `StaticViewModel`); concrete ViewModels override this to await
    /// their actual load task.
    func refresh() async
}

extension ViewModelProtocol {
    func cancelInFlightWork() {}
    func refresh() async {}
}

//
//  PersistSequencer.swift
//  TMinus
//

import Foundation

// MARK: - PersistSequencer

/// Stops a slow, older fetch from overwriting a newer result in the local cache.
/// Each logical resource should have its own sequencer.
actor PersistSequencer {
    private var nextTicket = 0
    private var lastPersistedTicket = 0

    init() {}

    /// Returns a ticket that records when the fetch started, regardless of when it completes.
    func startingFetch() -> Int {
        nextTicket += 1
        return nextTicket
    }

    /// Returns `false` if a newer fetch has already written its result.
    func shouldPersist(ticket: Int) -> Bool {
        guard ticket >= lastPersistedTicket else { return false }
        lastPersistedTicket = ticket
        return true
    }
}

//
//  PersistSequencerTests.swift
//  TMinusTests
//
//  Created by Sadegh on 18/08/2026.
//

import Testing
@testable import TMinus

@Suite("PersistSequencer")
struct PersistSequencerTests {
    @Test("A single fetch's ticket is always allowed to persist")
    func singleTicketPersists() async {
        let sequencer = PersistSequencer()
        let ticket = await sequencer.startingFetch()

        #expect(await sequencer.shouldPersist(ticket: ticket))
    }

    // The core scenario this exists for: an earlier-issued, slower fetch (e.g. an auto-triggered
    // `.useCache` load) resolves *after* a later-issued, faster one (e.g. a user-initiated
    // pull-to-refresh) has already persisted. The earlier fetch's write must be dropped rather
    // than clobber the later one's fresher result.
    @Test("A later-issued fetch's persist blocks an earlier-issued fetch's late-arriving persist")
    func laterTicketBlocksEarlierLateArrival() async {
        let sequencer = PersistSequencer()
        let earlierTicket = await sequencer.startingFetch()
        let laterTicket = await sequencer.startingFetch()

        // Later-issued fetch resolves and persists first (it's faster).
        #expect(await sequencer.shouldPersist(ticket: laterTicket))
        // Earlier-issued fetch resolves after, its persist must be rejected.
        #expect(await sequencer.shouldPersist(ticket: earlierTicket) == false)
    }

    @Test("An earlier-issued fetch's persist does not block a later-issued fetch's persist")
    func earlierTicketDoesNotBlockLaterTicket() async {
        let sequencer = PersistSequencer()
        let earlierTicket = await sequencer.startingFetch()
        let laterTicket = await sequencer.startingFetch()

        #expect(await sequencer.shouldPersist(ticket: earlierTicket))
        #expect(await sequencer.shouldPersist(ticket: laterTicket))
    }

    @Test("Three interleaved fetches only ever let the most-recently-issued surviving persist win")
    func onlyMostRecentlyIssuedTicketWins() async {
        let sequencer = PersistSequencer()
        let first = await sequencer.startingFetch()
        let second = await sequencer.startingFetch()
        let third = await sequencer.startingFetch()

        // Resolve out of issue order: third, then first, then second.
        #expect(await sequencer.shouldPersist(ticket: third))
        #expect(await sequencer.shouldPersist(ticket: first) == false)
        #expect(await sequencer.shouldPersist(ticket: second) == false)
    }
}

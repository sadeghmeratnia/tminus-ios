//
//  PaginationURLParserTests.swift
//  TMinus
//
//  Created by Sadegh on 16/08/2026.
//

import Testing
@testable import TMinus

// MARK: - PaginationURLParserTests

@Suite("PaginationURLParser")
struct PaginationURLParserTests {
    @Test("Returns nil for a nil URL string")
    func nilInput() {
        #expect(PaginationURLParser.pageNumber(from: nil, fallbackLimit: 20) == nil)
    }

    @Test("Returns nil for a malformed URL string")
    func malformedURL() {
        // A raw, unescaped space makes `URLComponents` fail to parse.
        #expect(PaginationURLParser.pageNumber(from: "not a url with spaces", fallbackLimit: 20) == nil)
    }

    @Test("Returns nil when the URL has no query items at all")
    func noQueryItems() {
        #expect(PaginationURLParser.pageNumber(from: "https://example.com/launches", fallbackLimit: 20) == nil)
    }

    @Test("Missing offset defaults to 0, yielding page 1")
    func missingOffsetDefaultsToZero() {
        let page = PaginationURLParser.pageNumber(from: "https://example.com/launches?limit=20", fallbackLimit: 20)
        #expect(page == 1)
    }

    @Test("Missing limit falls back to the caller-supplied limit")
    func missingLimitUsesFallback() {
        let page = PaginationURLParser.pageNumber(from: "https://example.com/launches?offset=40", fallbackLimit: 20)
        #expect(page == 3)
    }

    @Test("A non-positive limit query item falls back to the caller-supplied limit rather than dividing by zero/negative")
    func nonPositiveLimitFallsBack() {
        let page = PaginationURLParser.pageNumber(from: "https://example.com/launches?offset=40&limit=0", fallbackLimit: 20)
        #expect(page == 3)
    }

    @Test("A non-numeric offset/limit is treated as absent")
    func nonNumericValuesAreIgnored() {
        let page = PaginationURLParser.pageNumber(from: "https://example.com/launches?offset=abc&limit=xyz", fallbackLimit: 20)
        #expect(page == 1)
    }

    @Test("Computes the correct page for a clean offset/limit pair")
    func computesPageNumber() {
        let page = PaginationURLParser.pageNumber(from: "https://example.com/launches?offset=60&limit=20", fallbackLimit: 20)
        #expect(page == 4)
    }

    @Test("An offset that isn't a clean multiple of limit rounds down rather than crashing")
    func nonMultipleOffsetRoundsDown() {
        // 45 / 20 == 2 (integer division), so this should resolve to page 3, not assert/crash,
        // the parser must degrade gracefully on a server response that doesn't match the app's
        // usual offset/limit assumption, not treat it as a fatal condition.
        let page = PaginationURLParser.pageNumber(from: "https://example.com/launches?offset=45&limit=20", fallbackLimit: 20)
        #expect(page == 3)
    }

    @Test("A zero fallback limit is clamped to at least 1")
    func zeroFallbackLimitIsClamped() {
        let page = PaginationURLParser.pageNumber(from: "https://example.com/launches?offset=2", fallbackLimit: 0)
        #expect(page == 3)
    }

    @Test("A negative offset is treated as no further page rather than yielding a bogus page number")
    func negativeOffsetYieldsNil() {
        let page = PaginationURLParser.pageNumber(from: "https://example.com/launches?offset=-20&limit=20", fallbackLimit: 20)
        #expect(page == nil)
    }
}

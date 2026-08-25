//
//  FlexibleISO8601DateDecodingStrategyTests.swift
//  TMinusTests
//
//  Created by Sadegh on 17/08/2026.
//

import Foundation
import Testing
@testable import TMinus

@Suite("FlexibleISO8601DateDecodingStrategy")
struct FlexibleISO8601DateDecodingStrategyTests {
    @Test("Decodes a plain ISO 8601 timestamp with no fractional seconds")
    func decodesPlainTimestamp() throws {
        let date = try decode(#""2026-05-12T10:00:00Z""#)

        let components = Calendar(identifier: .gregorian).dateComponents(
            in: TimeZone(identifier: "UTC")!,
            from: date
        )
        #expect(components.year == 2026)
        #expect(components.month == 5)
        #expect(components.day == 12)
        #expect(components.hour == 10)
        #expect(components.minute == 0)
        #expect(components.second == 0)
    }

    @Test("Decodes an ISO 8601 timestamp with fractional seconds")
    func decodesFractionalSecondsTimestamp() throws {
        let date = try decode(#""2026-05-12T10:00:00.123Z""#)

        let components = Calendar(identifier: .gregorian).dateComponents(
            in: TimeZone(identifier: "UTC")!,
            from: date
        )
        #expect(components.second == 0)
        // Foundation's ISO 8601 fractional-seconds parsing rounds to the nearest millisecond
        // rather than truncating, this only asserts the value round-trips within a millisecond,
        // not exact floating-point equality.
        let nanoseconds = date.timeIntervalSince1970.truncatingRemainder(dividingBy: 1) * 1000
        #expect(abs(nanoseconds - 123) < 1)
    }

    @Test("Fractional-seconds timestamp and its plain equivalent decode to the same second")
    func fractionalAndPlainAgreeOnWholeSecond() throws {
        let plain = try decode(#""2026-05-12T10:00:00Z""#)
        let fractional = try decode(#""2026-05-12T10:00:00.999Z""#)

        #expect(Int(fractional.timeIntervalSince1970) - Int(plain.timeIntervalSince1970) == 0)
    }

    @Test("Throws a decoding error for a malformed date string rather than silently producing a wrong date")
    func throwsForMalformedString() {
        #expect(throws: DecodingError.self) {
            try decode(#""not-a-date""#)
        }
    }

    @Test("Throws a decoding error for an empty string")
    func throwsForEmptyString() {
        #expect(throws: DecodingError.self) {
            try decode(#""""#)
        }
    }
}

private extension FlexibleISO8601DateDecodingStrategyTests {
    struct Wrapper: Decodable {
        let value: Date
    }

    func decode(_ jsonDateLiteral: String) throws -> Date {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .flexibleISO8601
        let json = "{\"value\": \(jsonDateLiteral)}"
        return try decoder.decode(Wrapper.self, from: Data(json.utf8)).value
    }
}

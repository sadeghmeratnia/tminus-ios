//
//  FlexibleISO8601DateDecodingStrategy.swift
//  TMinus
//
//  Created by Sadegh on 13/08/2026.
//

import Foundation

/// Keeps date parsing safe for concurrent decodes by using stateless format styles.
private enum ISO8601Parsing {
    static let withFractionalSeconds = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    static let plain = Date.ISO8601FormatStyle()

    static func date(from string: String) -> Date? {
        (try? withFractionalSeconds.parse(string)) ?? (try? plain.parse(string))
    }
}

extension JSONDecoder.DateDecodingStrategy {
    /// Accepts ISO 8601 timestamps with or without fractional seconds.
    static let flexibleISO8601 = JSONDecoder.DateDecodingStrategy.custom { decoder in
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)

        if let date = ISO8601Parsing.date(from: string) {
            return date
        }

        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Expected a valid ISO 8601 date string, got \"\(string)\""
        )
    }
}

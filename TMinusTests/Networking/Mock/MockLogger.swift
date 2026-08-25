//
//  MockLogger.swift
//  TMinus
//
//  Created by Sadegh on 05/05/2026.
//

import Foundation
@testable import TMinus

/// Records every logged message instead of discarding it, so tests can assert *that* a failure
/// was actually logged (and at what level) rather than only that the call didn't crash, a
/// no-op mock can't distinguish "logged correctly" from "silently swallowed."
final class MockLogger: NetworkLogger, @unchecked Sendable {
    struct Entry: Equatable {
        let message: String
        let level: LogLevel
    }

    private let lock = NSLock()
    private var _entries: [Entry] = []

    var entries: [Entry] {
        lock.lock()
        defer { lock.unlock() }
        return _entries
    }

    func log(_ message: String, level: LogLevel) {
        lock.lock()
        defer { lock.unlock() }
        _entries.append(Entry(message: message, level: level))
    }
}

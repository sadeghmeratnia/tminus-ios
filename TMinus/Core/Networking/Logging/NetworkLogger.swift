//
//  NetworkLogger.swift
//  TMinus
//
//  Created by Sadegh on 22/04/2026.
//

import Foundation

// MARK: - NetworkLogger

protocol NetworkLogger: Sendable {
    func log(_ message: String, level: LogLevel)

    /// Logs `message` with `sensitiveDetail` appended, giving conformers the chance to mark
    /// `sensitiveDetail` specifically as OS-log-private, unlike every other message this app
    /// logs, which is deliberately `.public` (see `URLSessionNetworkClient`'s own redaction of
    /// URLs/headers for why that's normally fine). A failed response's raw body can echo
    /// request fields or, on a future endpoint, account-identifying detail, so it must not join
    /// the rest of this app's network logging at `.public` privacy in Console.app/sysdiagnose.
    func log(_ message: String, sensitiveDetail: String, level: LogLevel)
}

extension NetworkLogger {
    /// Default: no conformer-specific privacy split available, so this simply folds
    /// `sensitiveDetail` into the same message, correct for test/mock loggers, which don't
    /// write to any persistent, otherwise-`.public` log destination in the first place.
    /// `OSNetworkLogger` overrides this to actually mark `sensitiveDetail` `.private`.
    func log(_ message: String, sensitiveDetail: String, level: LogLevel) {
        log("\(message)\(sensitiveDetail)", level: level)
    }
}

// MARK: - LogLevel

enum LogLevel: Equatable {
    case debug
    case info
    case warning
    case error
}

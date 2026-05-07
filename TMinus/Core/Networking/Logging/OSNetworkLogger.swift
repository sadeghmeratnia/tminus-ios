//
//  OSNetworkLogger.swift
//  TMinus
//
//  Created by Sadegh on 22/04/2026.
//

import OSLog

struct OSNetworkLogger: NetworkLogger {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "app",
        category: "Network")

    func log(_ message: String, level: LogLevel) {
        switch level {
        case .debug:
            logger.debug("\(message)")
        case .info:
            logger.info("\(message)")
        case .warning:
            logger.warning("\(message)")
        case .error:
            logger.error("\(message)")
        }
    }
}

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
        category: "Network"
    )

    func log(_ message: String, level: LogLevel) {
        switch level {
        case .debug:
            logger.debug("\(message, privacy: .public)")
        case .info:
            logger.info("\(message, privacy: .public)")
        case .warning:
            logger.warning("\(message, privacy: .public)")
        case .error:
            logger.error("\(message, privacy: .public)")
        }
    }

    func log(_ message: String, sensitiveDetail: String, level: LogLevel) {
        switch level {
        case .debug:
            logger.debug("\(message, privacy: .public)\(sensitiveDetail, privacy: .private)")
        case .info:
            logger.info("\(message, privacy: .public)\(sensitiveDetail, privacy: .private)")
        case .warning:
            logger.warning("\(message, privacy: .public)\(sensitiveDetail, privacy: .private)")
        case .error:
            logger.error("\(message, privacy: .public)\(sensitiveDetail, privacy: .private)")
        }
    }
}

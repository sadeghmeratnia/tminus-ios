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
}

// MARK: - LogLevel

enum LogLevel {
    case debug
    case info
    case warning
    case error
}

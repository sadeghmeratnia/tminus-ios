//
//  MockLogger.swift
//  TMinus
//
//  Created by Sadegh on 05/05/2026.
//

@testable import TMinus
import Foundation

struct MockLogger: NetworkLogger {
    func log(_: String, level _: LogLevel) { }
}

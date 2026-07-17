//
//  MockLogger.swift
//  TMinus
//
//  Created by Sadegh on 05/05/2026.
//

import Foundation
@testable import TMinus

struct MockLogger: NetworkLogger {
    func log(_: String, level _: LogLevel) {}
}

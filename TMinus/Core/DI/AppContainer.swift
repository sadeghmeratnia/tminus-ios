//
//  AppContainer.swift
//  TMinus
//
//  Created by Sadegh on 22/04/2026.
//

import Foundation
import SwiftData

final class AppContainer {
    let networkClient: NetworkClientProtocol
    let modelContainer: ModelContainer
    let cache: DataCache
    let logger: NetworkLogger

    init(networkClient: NetworkClientProtocol,
         modelContainer: ModelContainer,
         cache: DataCache,
         logger: NetworkLogger) {
        self.networkClient = networkClient
        self.modelContainer = modelContainer
        self.cache = cache
        self.logger = logger
    }
}

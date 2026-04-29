//
//  RepositoryFactory.swift
//  TMinus
//
//  Created by Sadegh on 23/04/2026.
//

import Foundation

final class RepositoryFactory {
    private let networkingFactory: NetworkingFactory

    init(networkingFactory: NetworkingFactory) {
        self.networkingFactory = networkingFactory
    }
}

//
//  UseCaseFactory.swift
//  TMinus
//
//  Created by Sadegh on 23/04/2026.
//

import Foundation

final class UseCaseFactory {
    private let repositoryFactory: RepositoryFactory

    init(repositoryFactory: RepositoryFactory) {
        self.repositoryFactory = repositoryFactory
    }
}

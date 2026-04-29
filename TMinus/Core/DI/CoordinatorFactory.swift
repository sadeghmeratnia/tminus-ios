//
//  CoordinatorFactory.swift
//  TMinus
//
//  Created by Sadegh on 23/04/2026.
//

import Foundation

final class CoordinatorFactory {
    private let useCaseFactory: UseCaseFactory

    init(useCaseFactory: UseCaseFactory) {
        self.useCaseFactory = useCaseFactory
    }
}

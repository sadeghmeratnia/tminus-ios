//
//  FetchLaunchDetailUseCase.swift
//  TMinus
//
//  Created by Sadegh on 06/05/2026.
//

import Foundation

struct FetchLaunchDetailUseCase {
    private let repository: LaunchRepositoryProtocol

    init(repository: LaunchRepositoryProtocol) {
        self.repository = repository
    }

    func execute(id: String) async throws -> Launch {
        try await repository.fetchLaunchDetail(id: id)
    }
}

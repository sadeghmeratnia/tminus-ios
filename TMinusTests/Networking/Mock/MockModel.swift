//
//  MockModel.swift
//  TMinus
//
//  Created by Sadegh on 05/05/2026.
//

import Foundation
@testable import TMinus

struct MockModel: Codable, Sendable, Equatable {
    let id: Int
    let name: String
}
